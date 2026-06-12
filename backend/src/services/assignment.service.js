const { query, withTransaction } = require('../db/postgres');
const redis = require('../db/redis');
const { haversineDistanceKm } = require('../utils/distance.util');
const { addressToText } = require('../utils/address');
const { logger } = require('../utils/logger');

const ATTEMPT_TTL_SECONDS = 24 * 60 * 60;
const MAX_ASSIGNMENT_ATTEMPTS = 3;
const ASSIGNMENT_TIMEOUT_MS = 30_000;
const pendingAssignmentTimeouts = new Map();

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

/**
 * Enhanced scoring with multiple factors
 * - Distance: 35% (closer is better)
 * - Acceptance rate: 25% (higher is better)
 * - Current load: 20% (fewer active orders is better)
 * - Rating: 10% (higher is better)
 * - Zone familiarity: 10% (more deliveries in this zone is better)
 */
const computeScore = ({ 
  distanceKm, 
  acceptanceRate, 
  rating, 
  activeOrders = 0,
  zoneFamiliarity = 0 
}) => {
  // Distance component (0-100, decreases with distance)
  const distanceScore = Math.max(0, 100 - (distanceKm * 15));
  
  // Acceptance rate (0-100)
  const acceptanceScore = acceptanceRate * 100;
  
  // Load component (100 when no active orders, decreases by 25 per order)
  const loadScore = Math.max(0, 100 - (activeOrders * 25));
  
  // Rating component (0-100)
  const ratingScore = (rating / 5) * 100;
  
  // Zone familiarity (0-100, capped at 10 deliveries)
  const zoneScore = Math.min(100, zoneFamiliarity * 10);
  
  return (
    distanceScore * 0.35 +
    acceptanceScore * 0.25 +
    loadScore * 0.20 +
    ratingScore * 0.10 +
    zoneScore * 0.10
  );
};

/**
 * Get eligible partners within a radius with enhanced scoring
 * @param {Object} order - Order object
 * @param {number} maxDistanceKm - Maximum distance in kilometers
 * @param {number} excludePartnerId - Partner ID to exclude (for reassignment)
 */
const getEligiblePartners = async (order, maxDistanceKm = 5, excludePartnerId = null) => {
  const target = await getDeliveryTarget(order);
  
  // Get zone ID for zone familiarity calculation
  const orderZoneId = order.zone_id || null;
  
  const { rows } = await query(
    `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, dp.is_online, dp.approved,
            u.name, u.phone
     FROM delivery_partners dp
     JOIN users u ON u.id = dp.user_id
     WHERE dp.is_online = TRUE
       AND dp.approved = TRUE
       AND u.role = 'delivery'`
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
    if (distanceKm > maxDistanceKm) continue;

    // Get partner metrics
    const { rows: metrics } = await query(
      `SELECT
         COALESCE(SUM(CASE WHEN status IN ('ACCEPTED','PICKED','DELIVERED') THEN 1 ELSE 0 END),0)::float AS accepted_count,
         COUNT(*)::float AS total_count,
         COALESCE(AVG(CASE WHEN status = 'DELIVERED' AND rating IS NOT NULL THEN rating ELSE NULL END), 0) AS avg_rating
       FROM order_assignments
       WHERE delivery_partner_id = $1`,
      [partner.id]
    );

    // Get active orders count
    const { rows: activeRows } = await query(
      `SELECT COUNT(*) as active_count
       FROM order_assignments oa
       JOIN orders o ON o.id = oa.order_id
       WHERE oa.delivery_partner_id = $1
         AND o.status NOT IN ('DELIVERED','CANCELLED')`,
      [partner.id]
    );

    // Get zone familiarity (deliveries in this zone)
    let zoneFamiliarity = 0;
    if (orderZoneId) {
      const { rows: zoneRows } = await query(
        `SELECT COUNT(*) as zone_deliveries
         FROM order_assignments oa
         JOIN orders o ON o.id = oa.order_id
         WHERE oa.delivery_partner_id = $1
           AND o.zone_id = $2
           AND oa.status = 'DELIVERED'`,
        [partner.id, orderZoneId]
      );
      zoneFamiliarity = Number(zoneRows[0]?.zone_deliveries || 0);
    }

    const acceptedCount = Number(metrics[0]?.accepted_count || 0);
    const totalCount = Number(metrics[0]?.total_count || 0);
    const acceptanceRate = totalCount > 0 ? acceptedCount / totalCount : 1;
    const rating = Number(metrics[0]?.avg_rating || 4); // Default 4 if no ratings
    const activeOrders = Number(activeRows[0]?.active_count || 0);
    
    const score = computeScore({ 
      distanceKm, 
      acceptanceRate, 
      rating, 
      activeOrders,
      zoneFamiliarity 
    });

    filtered.push({
      id: Number(partner.id),
      userId: Number(partner.user_id),
      name: partner.name || '',
      phone: partner.phone || '',
      current_lat: plat,
      current_lng: plng,
      distanceKm,
      acceptanceRate,
      rating,
      activeOrders,
      zoneFamiliarity,
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

const buildPartnerAssignmentPayload = (order, partner) => {
  const rawAddress = order?.address;
  const addressText = addressToText(rawAddress);
  const lat = Number(rawAddress?.lat ?? rawAddress?.latitude);
  const lng = Number(rawAddress?.lng ?? rawAddress?.longitude);
  const distanceKm = Number.isFinite(partner.distanceKm)
    ? Number(partner.distanceKm.toFixed(1))
    : undefined;
  const totalAmount =
    order.total_amount != null ? Number(order.total_amount) : undefined;

  return {
    orderId: Number(order.id),
    totalAmount,
    amount: totalAmount,
    total_amount: totalAmount,
    total_price: totalAmount,
    address: addressText,
    customerAddress: addressText,
    delivery_address: addressText,
    paymentMode: order.payment_mode,
    assignmentStatus: 'ASSIGNED',
    distance: distanceKm,
    timeout: ASSIGNMENT_TIMEOUT_MS,
    partner: {
      id: Number(partner.id),
      name: partner.name || '',
      phone: partner.phone || '',
      lat: Number(partner.current_lat ?? 0),
      lng: Number(partner.current_lng ?? 0),
    },
    timestamp: new Date().toISOString(),
  };
};

const clearAssignmentTimeout = (orderId) => {
  const key = String(orderId);
  const timeoutId = pendingAssignmentTimeouts.get(key);
  if (timeoutId) {
    clearTimeout(timeoutId);
    pendingAssignmentTimeouts.delete(key);
  }
};

const scheduleAssignmentTimeout = ({ orderId, partnerId, partnerUserId, io }) => {
  clearAssignmentTimeout(orderId);

  const timeoutId = setTimeout(async () => {
    pendingAssignmentTimeouts.delete(String(orderId));
    try {
      const { rows } = await query(
        `SELECT status, delivery_partner_id
         FROM order_assignments
         WHERE order_id = $1`,
        [orderId]
      );
      const assignment = rows[0];
      if (!assignment || assignment.status !== 'ASSIGNED') return;
      if (Number(assignment.delivery_partner_id) !== Number(partnerId)) return;

      await query(
        `UPDATE order_assignments
         SET status = 'CANCELLED', updated_at = NOW()
         WHERE order_id = $1`,
        [orderId]
      );

      emitAssignmentCancelled(io, orderId, partnerUserId, 'timeout');

      await assignOrderToPartner({
        orderId,
        io,
        excludePartnerId: partnerId,
      });
    } catch (err) {
      logger.error('assignment_timeout_failed', {
        orderId,
        error: err.message,
      });
    }
  }, ASSIGNMENT_TIMEOUT_MS);

  pendingAssignmentTimeouts.set(String(orderId), timeoutId);
};

const emitPartnerAssigned = (io, order, partner) => {
  if (!io || !order || !partner) return;
  const partnerUserId = Number(partner.userId ?? partner.user_id);
  const payload = buildPartnerAssignmentPayload(order, partner);
  if (partnerUserId) {
    io.to(`user:${partnerUserId}`).emit('order:assigned', payload);
    io.to(`delivery_${partnerUserId}`).emit('order:assigned', payload);
  }
};

const emitAssignmentCancelled = (io, orderId, partnerUserId, reason = 'cancelled') => {
  if (!io) return;
  const payload = {
    orderId: Number(orderId),
    reason,
    timestamp: new Date().toISOString(),
  };
  if (partnerUserId) {
    io.to(`user:${Number(partnerUserId)}`).emit('order:assignment_cancelled', payload);
    io.to(`delivery_${Number(partnerUserId)}`).emit('order:assignment_cancelled', payload);
  }
  io.to('admin_room').emit('order:assignment_cancelled', payload);
};

const emitCustomerPartnerAssigned = (io, order, partner) => {
  if (!io || !order || !partner) return;
  const customerPayload = {
    orderId: Number(order.id),
    partner: {
      id: Number(partner.id),
      name: partner.name,
      phone: partner.phone,
      lat: Number(partner.current_lat ?? 0),
      lng: Number(partner.current_lng ?? 0),
    },
    timestamp: new Date().toISOString(),
  };
  if (order.customer_id) {
    io.to(`customer_${Number(order.customer_id)}`).emit(
      'order:partner_assigned',
      customerPayload
    );
  }
  io.to('admin_room').emit('order:partner_assigned', customerPayload);
};

const emitAssignmentSuccess = (io, order, partner) => {
  if (!io || !order || !partner) return;
  emitCustomerPartnerAssigned(io, order, partner);
  emitPartnerAssigned(io, order, partner);
};

const emitRouteZoneAssigned = (io, { zoneId, riderUserId, riderId, orderIds, routeOrder }) => {
  if (!io || !riderUserId) return;
  const payload = {
    zoneId: Number(zoneId),
    riderId: Number(riderId),
    orderIds: (orderIds || []).map(Number),
    routeOrder: (routeOrder || orderIds || []).map(Number),
    orderCount: (orderIds || []).length,
    timestamp: new Date().toISOString(),
  };
  const userRoom = `user:${Number(riderUserId)}`;
  const deliveryRoom = `delivery_${Number(riderUserId)}`;
  io.to(userRoom).emit('route:zone_assigned', payload);
  io.to(deliveryRoom).emit('route:zone_assigned', payload);
  io.to('admin_room').emit('route:zone_assigned', payload);
};

/**
 * Assign order to partner with fallback tier system
 * Tier 1: Within 3km (best matches)
 * Tier 2: Within 5km
 * Tier 3: Within 8km (extended range)
 * Tier 4: Broadcast to all online riders
 */
const assignOrderToPartner = async ({ orderId, io, excludePartnerId = null }) => {
  const attemptKey = `assign:attempts:${orderId}`;
  const attempts = await redis.incr(attemptKey);
  await redis.expire(attemptKey, ATTEMPT_TTL_SECONDS);

  if (attempts > MAX_ASSIGNMENT_ATTEMPTS) {
    emitAssignmentFailure(io, orderId, attempts);
    return { assigned: false, reason: 'max_attempts_exceeded', attempts };
  }

  const { rows: orderRows } = await query(
    `SELECT id, customer_id, status, address, total_amount, payment_mode, zone_id
     FROM orders
     WHERE id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return { assigned: false, reason: 'order_not_found', attempts };
  if (!['CONFIRMED', 'PACKED'].includes(order.status)) {
    return { assigned: false, reason: 'order_not_assignable', attempts };
  }

  // Fallback tier system
  const tiers = [
    { distance: 3, label: 'nearby' },
    { distance: 5, label: 'medium' },
    { distance: 8, label: 'extended' },
  ];

  let candidates = [];
  let usedTier = null;

  // Try each tier in order
  for (const tier of tiers) {
    candidates = await getEligiblePartners(order, tier.distance, excludePartnerId);
    if (candidates.length > 0) {
      usedTier = tier.label;
      break;
    }
  }

  // Tier 4: Broadcast to all online riders if no one found
  if (!candidates.length) {
    // Get all online riders regardless of distance
    const { rows } = await query(
      `SELECT dp.id, dp.user_id, u.name, u.phone
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.is_online = TRUE
         AND dp.approved = TRUE
         AND u.role = 'delivery'`
    );

    if (rows.length > 0) {
      // Broadcast to all riders
      const broadcastPayload = {
        orderId: Number(order.id),
        totalAmount: order.total_amount ? Number(order.total_amount) : undefined,
        address: order.address,
        paymentMode: order.payment_mode,
        broadcast: true,
        timestamp: new Date().toISOString(),
      };

      if (io) {
        io.to('riders').emit('order:broadcast', broadcastPayload);
      }

      // Also emit to admin
      if (io) {
        io.to('admin_room').emit('order:broadcast_sent', {
          orderId: Number(orderId),
          riderCount: rows.length,
          timestamp: new Date().toISOString(),
        });
      }

      return { 
        assigned: false, 
        reason: 'broadcasted_to_all_riders', 
        attempts,
        riderCount: rows.length 
      };
    }

    // No riders available at all
    if (attempts >= MAX_ASSIGNMENT_ATTEMPTS) {
      emitAssignmentFailure(io, orderId, attempts);
    }
    return { assigned: false, reason: 'no_eligible_partners', attempts };
  }

  // Assign to best candidate
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

  emitAssignmentSuccess(io, order, selected);
  scheduleAssignmentTimeout({
    orderId,
    partnerId: selected.id,
    partnerUserId: selected.userId,
    io,
  });
  
  return { 
    assigned: true, 
    partner: selected, 
    attempts,
    tier: usedTier,
    distanceKm: selected.distanceKm,
    score: selected.score
  };
};

module.exports = {
  assignOrderToPartner,
  emitAssignmentSuccess,
  emitCustomerPartnerAssigned,
  emitPartnerAssigned,
  emitAssignmentCancelled,
  emitRouteZoneAssigned,
  clearAssignmentTimeout,
  scheduleAssignmentTimeout,
  MAX_ASSIGNMENT_ATTEMPTS,
  ASSIGNMENT_TIMEOUT_MS,
};
