const { query, withTransaction } = require('../db/postgres');
const redis = require('../db/redis');
const { haversineDistanceKm } = require('../utils/distance.util');

const ATTEMPT_TTL_SECONDS = 24 * 60 * 60;
const MAX_ASSIGNMENT_ATTEMPTS = 3;

const getDeliveryTarget = async (order) => {
  const rawAddress = order?.address;
  if (rawAddress && typeof rawAddress === 'object') {
    const lat = Number(rawAddress.lat);
    const lng = Number(rawAddress.lng);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng };
    }
  }

  try {
    const { rows } = await query(
      `SELECT center_lat, center_lng
       FROM store_settings
       ORDER BY updated_at DESC
       LIMIT 1`
    );
    const lat = Number(rows[0]?.center_lat || 0);
    const lng = Number(rows[0]?.center_lng || 0);
    return { lat, lng };
  } catch {
    return { lat: 0, lng: 0 };
  }
};

const computeScore = ({ distanceKm, acceptanceRate, rating, todayBonus }) => {
  const distanceComponent = distanceKm > 0 ? (1 / distanceKm) * 40 : 40;
  return distanceComponent + acceptanceRate * 30 + rating * 20 + todayBonus * 10;
};

const getEligiblePartners = async (order, excludePartnerId = null) => {
  const target = await getDeliveryTarget(order);
  const { rows } = await query(
    `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, dp.is_online, dp.approved,
            u.name, u.phone
     FROM delivery_partners dp
     JOIN users u ON u.id = dp.user_id
     WHERE dp.is_online = TRUE
       AND dp.approved = TRUE
       AND NOT EXISTS (
         SELECT 1
         FROM order_assignments oa
         JOIN orders o ON o.id = oa.order_id
         WHERE oa.delivery_partner_id = dp.id
           AND o.status NOT IN ('DELIVERED','CANCELLED')
       )`
  );

  const filtered = [];
  for (const partner of rows) {
    if (excludePartnerId && Number(partner.id) === Number(excludePartnerId)) continue;
    const plat = Number(partner.current_lat);
    const plng = Number(partner.current_lng);
    if (!Number.isFinite(plat) || !Number.isFinite(plng)) continue;
    if (!Number.isFinite(target.lat) || !Number.isFinite(target.lng) || target.lat === 0 || target.lng === 0) {
      continue;
    }

    const distanceKm = haversineDistanceKm(plat, plng, target.lat, target.lng);
    if (distanceKm > 5) continue;

    const { rows: metrics } = await query(
      `SELECT
         COALESCE(SUM(CASE WHEN status IN ('ACCEPTED','PICKED','DELIVERED') THEN 1 ELSE 0 END),0)::float AS accepted_count,
         COUNT(*)::float AS total_count,
         COALESCE(SUM(CASE WHEN status = 'DELIVERED' AND assigned_at::date = CURRENT_DATE THEN 1 ELSE 0 END),0)::float AS delivered_today
       FROM order_assignments
       WHERE delivery_partner_id = $1`,
      [partner.id]
    );

    const acceptedCount = Number(metrics[0]?.accepted_count || 0);
    const totalCount = Number(metrics[0]?.total_count || 0);
    const deliveredToday = Number(metrics[0]?.delivered_today || 0);
    const acceptanceRate = totalCount > 0 ? acceptedCount / totalCount : 1;
    const rating = 5;
    const todayBonus = deliveredToday < 5 ? 1 : 0;
    const score = computeScore({ distanceKm, acceptanceRate, rating, todayBonus });

    filtered.push({
      id: Number(partner.id),
      userId: Number(partner.user_id),
      name: partner.name || '',
      phone: partner.phone || '',
      current_lat: plat,
      current_lng: plng,
      distanceKm,
      score,
    });
  }

  filtered.sort((a, b) => b.score - a.score);
  return filtered;
};

const emitAssignmentFailure = (io, orderId, attempts) => {
  if (!io) return;
  io.to('admin_room').emit('order:assignment_failed', {
    orderId: Number(orderId),
    attempts,
    timestamp: new Date().toISOString(),
  });
};

const emitAssignmentSuccess = (io, orderId, customerId, partner) => {
  if (!io) return;
  const payload = {
    orderId: Number(orderId),
    partner: {
      id: Number(partner.id),
      name: partner.name,
      phone: partner.phone,
      lat: Number(partner.current_lat),
      lng: Number(partner.current_lng),
    },
    timestamp: new Date().toISOString(),
  };
  if (customerId) {
    io.to(`customer_${Number(customerId)}`).emit('order:partner_assigned', payload);
  }
  io.to('admin_room').emit('order:partner_assigned', {
    ...payload,
  });
};

const assignOrderToPartner = async ({ orderId, io, excludePartnerId = null }) => {
  const attemptKey = `assign:attempts:${orderId}`;
  const attempts = await redis.incr(attemptKey);
  await redis.expire(attemptKey, ATTEMPT_TTL_SECONDS);

  if (attempts > MAX_ASSIGNMENT_ATTEMPTS) {
    emitAssignmentFailure(io, orderId, attempts);
    return { assigned: false, reason: 'max_attempts_exceeded', attempts };
  }

  const { rows: orderRows } = await query(
    `SELECT id, customer_id, status, address
     FROM orders
     WHERE id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return { assigned: false, reason: 'order_not_found', attempts };
  if (!['CONFIRMED', 'PACKED'].includes(order.status)) {
    return { assigned: false, reason: 'order_not_assignable', attempts };
  }

  const candidates = await getEligiblePartners(order, excludePartnerId);
  if (!candidates.length) {
    if (attempts >= MAX_ASSIGNMENT_ATTEMPTS) {
      emitAssignmentFailure(io, orderId, attempts);
    }
    return { assigned: false, reason: 'no_eligible_partners', attempts };
  }

  const selected = candidates[0];
  await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status, assigned_at)
       VALUES ($1, $2, 'ASSIGNED', NOW())
       ON CONFLICT (order_id)
       DO UPDATE SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = 'ASSIGNED', assigned_at = NOW()`,
      [orderId, selected.id]
    );
  });

  emitAssignmentSuccess(io, orderId, order.customer_id, selected);
  return { assigned: true, partner: selected, attempts };
};

module.exports = {
  assignOrderToPartner,
  MAX_ASSIGNMENT_ATTEMPTS,
};
