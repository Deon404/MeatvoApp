const { query, withTransaction } = require('../db/postgres');
const redis = require('../db/redis');
const { haversineDistanceKm } = require('../utils/distance.util');
const { addressToText } = require('../utils/address');
const { logger } = require('../utils/logger');
const { tryJoinBatchWindow, scheduleBatchAssignment } = require('./order-batcher');
const { ensureDeliveryOTP } = require('./deliveryProof.service');

const ATTEMPT_TTL_SECONDS = 24 * 60 * 60;
const MAX_ASSIGNMENT_ATTEMPTS = 3;
const ASSIGNMENT_TIMEOUT_MS = Number(process.env.ASSIGNMENT_TIMEOUT_MS || 10_000);
const SMALL_FLEET_THRESHOLD = Number(process.env.SMALL_FLEET_THRESHOLD || 3);
const pendingAssignmentTimeouts = new Map();

const assignableOrderStatuses = new Set(['PACKED']);
const activeAssignmentStatuses = new Set(['ASSIGNED', 'ACCEPTED', 'PICKED']);

const persistPartnerAssignment = async (orderId, partnerId) => {
  await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status, assigned_at)
       VALUES ($1, $2, 'ASSIGNED', NOW())
       ON CONFLICT (order_id)
       DO UPDATE SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = 'ASSIGNED', assigned_at = NOW()`,
      [orderId, partnerId]
    );
  });
};

const getFirstApprovedPartner = async (excludePartnerId = null) => {
  const { rows } = await query(
    `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, u.name, u.phone
     FROM delivery_partners dp
     JOIN users u ON u.id = dp.user_id
     WHERE dp.approved = TRUE
     ORDER BY dp.is_online DESC, dp.id ASC`
  );

  for (const row of rows) {
    if (excludePartnerId && Number(row.id) === Number(excludePartnerId)) continue;
    return {
      id: Number(row.id),
      userId: Number(row.user_id),
      name: row.name || '',
      phone: row.phone || '',
      current_lat: row.current_lat,
      current_lng: row.current_lng,
      distanceKm: 0,
    };
  }
  return null;
};

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
       AND dp.approved = TRUE`
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

const getStoreLocation = async () => {
  try {
    const { rows } = await query(
      `SELECT center_lat, center_lng
       FROM store_settings
       ORDER BY updated_at DESC
       LIMIT 1`
    );
    return {
      lat: Number(rows[0]?.center_lat || 0),
      lng: Number(rows[0]?.center_lng || 0),
    };
  } catch {
    return { lat: 0, lng: 0 };
  }
};

const emitOrderAutoAccepted = (io, order, partner) => {
  if (!io || !order || !partner) return;
  const payload = {
    orderId: Number(order.id),
    autoAccepted: true,
    reason: 'nearest_store_rider',
    partner: {
      id: Number(partner.id),
      name: partner.name || '',
      phone: partner.phone || '',
    },
    timestamp: new Date().toISOString(),
  };
  const userId = Number(partner.userId);
  if (userId) {
    io.to(`user:${userId}`).emit('order:auto_accepted', payload);
    io.to(`delivery_${userId}`).emit('order:auto_accepted', payload);
  }
};

/**
 * After popup timeout: auto-accept order for the online rider nearest to store.
 */
const autoAcceptNearestStoreRider = async ({
  orderId,
  io,
  previousPartnerId = null,
  previousPartnerUserId = null,
}) => {
  const { rows: orderRows } = await query(
    `SELECT id, customer_id, status, address, total_amount, payment_mode
     FROM orders WHERE id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return { autoAccepted: false, reason: 'order_not_found' };
  if (!['CONFIRMED', 'PACKED'].includes(order.status)) {
    return { autoAccepted: false, reason: 'order_not_assignable' };
  }

  const { rows: assignmentRows } = await query(
    `SELECT status, delivery_partner_id FROM order_assignments WHERE order_id = $1`,
    [orderId]
  );
  const assignment = assignmentRows[0];
  if (!assignment || assignment.status !== 'ASSIGNED') {
    return { autoAccepted: false, reason: 'not_pending_acceptance' };
  }

  const store = await getStoreLocation();
  if (!store.lat || !store.lng) {
    return { autoAccepted: false, reason: 'no_store_location' };
  }

  const { rows: riders } = await query(
    `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, u.name, u.phone
     FROM delivery_partners dp
     JOIN users u ON u.id = dp.user_id
     WHERE dp.is_online = TRUE
       AND dp.approved = TRUE`
  );

  let nearest = null;
  let nearestKm = Infinity;
  for (const rider of riders) {
    let plat = Number(rider.current_lat);
    let plng = Number(rider.current_lng);
    if (!Number.isFinite(plat) || !Number.isFinite(plng)) {
      plat = store.lat;
      plng = store.lng;
    }
    const km = haversineDistanceKm(plat, plng, store.lat, store.lng);
    if (km < nearestKm) {
      nearestKm = km;
      nearest = {
        id: Number(rider.id),
        userId: Number(rider.user_id),
        name: rider.name || '',
        phone: rider.phone || '',
        current_lat: plat,
        current_lng: plng,
        distanceKm: km,
      };
    }
  }

  if (!nearest) {
    return { autoAccepted: false, reason: 'no_online_riders' };
  }

  await withTransaction(async (client) => {
    const { rowCount } = await client.query(
      `UPDATE order_assignments
       SET delivery_partner_id = $1, status = 'ACCEPTED', updated_at = NOW()
       WHERE order_id = $2 AND status = 'ASSIGNED'`,
      [nearest.id, orderId]
    );
    if (!rowCount) {
      const err = new Error('Assignment no longer pending');
      err.code = 'NOT_PENDING';
      throw err;
    }
    await client.query(
      `UPDATE orders SET status = 'OUT_FOR_DELIVERY', updated_at = NOW() WHERE id = $1`,
      [orderId]
    );
  });

  clearAssignmentTimeout(orderId);

  const previousId = Number(previousPartnerId ?? assignment.delivery_partner_id);
  if (previousId && previousId !== nearest.id && previousPartnerUserId) {
    emitAssignmentCancelled(io, orderId, previousPartnerUserId, 'auto_reassigned');
  } else if (previousPartnerUserId && previousId === nearest.id) {
    emitAssignmentCancelled(io, orderId, previousPartnerUserId, 'timeout');
  }

  emitOrderAutoAccepted(io, order, nearest);
  emitCustomerPartnerAssigned(io, order, nearest);

  ensureDeliveryOTP(orderId).catch(() => {});

  if (io) {
    io.to('admin_room').emit('order:updated', {
      orderId: Number(orderId),
      status: 'OUT_FOR_DELIVERY',
      autoAccepted: true,
      updatedAt: new Date().toISOString(),
    });
    if (order.customer_id) {
      const statusPayload = {
        orderId: Number(orderId),
        status: 'OUT_FOR_DELIVERY',
        updatedAt: new Date().toISOString(),
      };
      io.to(`customer_${Number(order.customer_id)}`).emit('order:status_updated', statusPayload);
      io.to(`customer_${Number(order.customer_id)}`).emit('order:status_update', statusPayload);
    }
  }

  logger.info('order_auto_accepted_nearest_store', {
    orderId,
    partnerId: nearest.id,
    distanceKm: Number(nearestKm.toFixed(2)),
  });

  return { autoAccepted: true, partner: nearest, distanceKm: nearestKm };
};

const clearAssignmentTimeout = (orderId) => {
  const key = String(orderId);
  const timeoutId = pendingAssignmentTimeouts.get(key);
  if (timeoutId) {
    clearTimeout(timeoutId);
    pendingAssignmentTimeouts.delete(key);
  }
};

/**
 * Cancel an active rider assignment for an order (DB update only).
 * Call notifyRiderAssignmentCancelled after the surrounding transaction commits.
 * @returns {{ cancelled: boolean, partnerUserId: number|null }}
 */
const cancelRiderAssignmentForOrder = async ({ orderId, dbClient = null }) => {
  const runQuery = dbClient ? dbClient.query.bind(dbClient) : query;
  const { rows } = await runQuery(
    `SELECT dp.user_id AS partner_user_id
     FROM order_assignments oa
     JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
     WHERE oa.order_id = $1
       AND oa.status = ANY($2::assignment_status[])`,
    [orderId, ['ASSIGNED', 'ACCEPTED', 'PICKED']]
  );

  const partnerUserId = rows[0]?.partner_user_id ?? null;
  if (!partnerUserId) {
    return { cancelled: false, partnerUserId: null };
  }

  await runQuery(
    `UPDATE order_assignments
     SET status = 'CANCELLED', updated_at = NOW()
     WHERE order_id = $1`,
    [orderId]
  );

  return { cancelled: true, partnerUserId: Number(partnerUserId) };
};

const notifyRiderAssignmentCancelled = ({
  orderId,
  partnerUserId,
  io,
  reason = 'order_cancelled',
}) => {
  if (!partnerUserId) return;
  clearAssignmentTimeout(orderId);
  emitAssignmentCancelled(io, orderId, partnerUserId, reason);
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

      const autoResult = await autoAcceptNearestStoreRider({
        orderId,
        io,
        previousPartnerId: partnerId,
        previousPartnerUserId: partnerUserId,
      });

      if (autoResult.autoAccepted) return;
    } catch (err) {
      if (err.code === 'NOT_PENDING') return;
      logger.error('assignment_auto_accept_failed', {
        orderId,
        error: err.message,
      });
    }

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

  if (order.customer_id) {
    const statusPayload = {
      orderId: Number(order.id),
      status: order.status || 'PACKED',
      message: 'Rider assigned, preparing your delivery',
      updatedAt: new Date().toISOString(),
    };
    io.to(`customer_${Number(order.customer_id)}`).emit('order:status_updated', statusPayload);
    io.to(`customer_${Number(order.customer_id)}`).emit('order:status_update', statusPayload);
  }

  emitPartnerAssigned(io, order, partner);
};

const assignWithBatching = async ({
  orderId,
  selected,
  io,
  attempts,
  tier,
  distanceKm = 0,
  score,
}) => {
  const onAssigned = (assignedOrderIds) => {
    for (const assignedOrderId of assignedOrderIds) {
      scheduleAssignmentTimeout({
        orderId: assignedOrderId,
        partnerId: selected.id,
        partnerUserId: selected.userId,
        io,
      });
    }
  };

  const result = await scheduleBatchAssignment({
    triggerOrderId: orderId,
    riderId: selected.id,
    riderUserId: selected.userId,
    io,
    onAssigned,
  });

  if (result.immediate) {
    if (!result.assignedOrderIds?.length) {
      return { assigned: true, reason: 'already_assigned', attempts };
    }

    return {
      assigned: true,
      partner: selected,
      attempts,
      tier,
      distanceKm,
      score,
      batchOrderIds: result.assignedOrderIds,
      batchSize: result.assignedOrderIds.length,
    };
  }

  return {
    assigned: true,
    partner: selected,
    attempts,
    tier,
    distanceKm,
    score,
    batchPending: true,
    batchAnchor: result.anchorOrderId,
    batchWaitMs: result.waitMs,
    batchJoined: Boolean(result.joined),
  };
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
    `SELECT id, customer_id, status, address, total_amount, payment_mode
     FROM orders
     WHERE id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return { assigned: false, reason: 'order_not_found', attempts };
  if (!assignableOrderStatuses.has(order.status)) {
    return { assigned: false, reason: 'order_not_assignable', attempts };
  }

  const { rows: existingAssignmentRows } = await query(
    'SELECT status FROM order_assignments WHERE order_id = $1 LIMIT 1',
    [orderId]
  );
  const existingAssignment = existingAssignmentRows[0];
  if (
    existingAssignment &&
    activeAssignmentStatuses.has(existingAssignment.status)
  ) {
    return { assigned: true, reason: 'already_assigned', attempts };
  }

  const batchJoin = await tryJoinBatchWindow(orderId);
  if (batchJoin) {
    return {
      assigned: true,
      reason: 'batch_pending',
      batchAnchor: batchJoin.anchorOrderId,
      batchStatus: batchJoin.status,
      attempts,
    };
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

  // Tier 4: Broadcast to all online riders if no one found in distance tiers
  if (!candidates.length) {
    const { rows } = await query(
      `SELECT dp.id, dp.user_id, u.name, u.phone
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.is_online = TRUE
         AND dp.approved = TRUE`
    );

    if (rows.length > 0) {
      // Startup / small fleet: auto-assign directly when only a few riders are online.
      if (rows.length <= SMALL_FLEET_THRESHOLD) {
        const selected = {
          id: Number(rows[0].id),
          userId: Number(rows[0].user_id),
          name: rows[0].name || '',
          phone: rows[0].phone || '',
          distanceKm: 0,
        };

        return assignWithBatching({
          orderId,
          selected,
          io,
          attempts,
          tier: 'small_fleet',
          distanceKm: 0,
        });
      }

      const broadcastPayload = {
        orderId: Number(order.id),
        totalAmount: order.total_amount ? Number(order.total_amount) : undefined,
        amount: order.total_amount ? Number(order.total_amount) : undefined,
        total_amount: order.total_amount ? Number(order.total_amount) : undefined,
        total_price: order.total_amount ? Number(order.total_amount) : undefined,
        address: addressToText(order.address),
        customerAddress: addressToText(order.address),
        delivery_address: addressToText(order.address),
        paymentMode: order.payment_mode,
        broadcast: true,
        timestamp: new Date().toISOString(),
      };

      if (io) {
        for (const rider of rows) {
          const riderUserId = Number(rider.user_id);
          if (!Number.isFinite(riderUserId)) continue;
          io.to(`user:${riderUserId}`).emit('order:assigned', broadcastPayload);
          io.to(`delivery_${riderUserId}`).emit('order:assigned', broadcastPayload);
          io.to(`user:${riderUserId}`).emit('order:broadcast', broadcastPayload);
        }
        io.to('riders').emit('order:broadcast', broadcastPayload);
      }

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
        riderCount: rows.length,
      };
    }

    // No online riders in broadcast tier — fallback to any approved partner
    const fallbackPartner = await getFirstApprovedPartner(excludePartnerId);
    if (fallbackPartner) {
      return assignWithBatching({
        orderId,
        selected: fallbackPartner,
        io,
        attempts,
        tier: 'fallback_approved',
        distanceKm: 0,
      });
    }

    if (attempts >= MAX_ASSIGNMENT_ATTEMPTS) {
      emitAssignmentFailure(io, orderId, attempts);
    }
    return { assigned: false, reason: 'no_eligible_partners', attempts };
  }

  const selected = candidates[0];
  return assignWithBatching({
    orderId,
    selected,
    io,
    attempts,
    tier: usedTier,
    distanceKm: selected.distanceKm,
    score: selected.score,
  });
};

const retryAssignOrderToPartner = async ({
  orderId,
  io,
  excludePartnerId = null,
  resetAttempts = false,
}) => {
  if (resetAttempts) {
    await redis.del(`assign:attempts:${orderId}`);
  }
  return assignOrderToPartner({ orderId, io, excludePartnerId });
};

const manualAssignOrderToPartner = async ({
  orderId,
  deliveryPartnerId,
  io,
}) => {
  const partnerId = Number(deliveryPartnerId);
  if (!Number.isFinite(partnerId) || partnerId <= 0) {
    return { assigned: false, reason: 'invalid_partner_id' };
  }

  const { rows: orderRows } = await query(
    `SELECT id, customer_id, status, address, total_amount, payment_mode
     FROM orders
     WHERE id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return { assigned: false, reason: 'order_not_found' };
  if (!assignableOrderStatuses.has(order.status)) {
    return { assigned: false, reason: 'order_not_assignable' };
  }

  const { rows: partnerRows } = await query(
    `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, dp.approved, u.name, u.phone
     FROM delivery_partners dp
     JOIN users u ON u.id = dp.user_id
     WHERE dp.id = $1`,
    [partnerId]
  );
  const partnerRow = partnerRows[0];
  if (!partnerRow) return { assigned: false, reason: 'partner_not_found' };
  if (!partnerRow.approved) return { assigned: false, reason: 'partner_not_approved' };

  const selected = {
    id: Number(partnerRow.id),
    userId: Number(partnerRow.user_id),
    name: partnerRow.name || '',
    phone: partnerRow.phone || '',
    current_lat: partnerRow.current_lat,
    current_lng: partnerRow.current_lng,
    distanceKm: 0,
  };

  await persistPartnerAssignment(orderId, selected.id);
  await redis.del(`assign:attempts:${orderId}`);
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
    tier: 'manual',
    distanceKm: 0,
  };
};

const ensureOrderAssigned = async ({ orderId, io }) => {
  const { rows } = await query(
    'SELECT id, status FROM order_assignments WHERE order_id = $1 LIMIT 1',
    [orderId]
  );
  const existing = rows[0];
  if (existing && activeAssignmentStatuses.has(existing.status)) {
    return { assigned: true, reason: 'already_assigned' };
  }

  const attemptsRaw = await redis.get(`assign:attempts:${orderId}`);
  const attempts = attemptsRaw ? Number(attemptsRaw) : 0;
  if (attempts >= MAX_ASSIGNMENT_ATTEMPTS) {
    return retryAssignOrderToPartner({ orderId, io, resetAttempts: true });
  }
  return assignOrderToPartner({ orderId, io });
};

module.exports = {
  assignOrderToPartner,
  retryAssignOrderToPartner,
  manualAssignOrderToPartner,
  ensureOrderAssigned,
  assignableOrderStatuses,
  autoAcceptNearestStoreRider,
  emitAssignmentSuccess,
  emitCustomerPartnerAssigned,
  emitPartnerAssigned,
  emitAssignmentCancelled,
  emitRouteZoneAssigned,
  clearAssignmentTimeout,
  scheduleAssignmentTimeout,
  cancelRiderAssignmentForOrder,
  notifyRiderAssignmentCancelled,
  MAX_ASSIGNMENT_ATTEMPTS,
  ASSIGNMENT_TIMEOUT_MS,
};
