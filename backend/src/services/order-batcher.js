const { query } = require('../db/postgres');
const { haversineKm } = require('../modules/delivery/route-optimizer');
const { addressToText } = require('../utils/address');
const { logger } = require('../utils/logger');

const BATCH_RADIUS_KM = 2.0;
const MAX_BATCH_SIZE = 4;
const BATCH_WAIT_MS = 3 * 60 * 1000;
/** Store→customer distance above this skips the batch wait (edge-of-zone orders). */
const EDGE_ZONE_BATCH_SKIP_KM = 4;

const assignableOrderStatuses = ['PACKED'];
const activeAssignmentStatuses = ['ASSIGNED', 'ACCEPTED', 'PICKED'];

/** @type {Map<number, { riderId: number, riderUserId: number, io: any, lat: number, lng: number, orderIds: Set<number>, timer: NodeJS.Timeout }>} */
const pendingBatchWindows = new Map();

function resolveBatchWaitMs() {
  const env = Number(process.env.BATCH_WAIT_MS);
  return Number.isFinite(env) && env >= 0 ? env : BATCH_WAIT_MS;
}

async function getOrderCoords(orderId) {
  const { rows } = await query(
    `SELECT (address->>'lat')::numeric AS lat,
       (address->>'lng')::numeric AS lng
     FROM orders
     WHERE id = $1`,
    [orderId]
  );
  const lat = Number(rows[0]?.lat);
  const lng = Number(rows[0]?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }
  return { lat, lng };
}

async function getStoreCenter() {
  const { rows } = await query(
    `SELECT center_lat, center_lng
     FROM store_settings
     ORDER BY updated_at DESC
     LIMIT 1`
  );
  const lat = Number(rows[0]?.center_lat);
  const lng = Number(rows[0]?.center_lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }
  return { lat, lng };
}

/** Haversine distance from store center to the order delivery address (km). */
async function getStoreToCustomerDistanceKm(orderId) {
  const [coords, store] = await Promise.all([
    getOrderCoords(orderId),
    getStoreCenter(),
  ]);
  if (!coords || !store) return null;
  return haversineKm(store.lat, store.lng, coords.lat, coords.lng);
}

async function resolveEffectiveBatchWaitMs(orderId) {
  const baseWaitMs = resolveBatchWaitMs();
  const distanceKm = await getStoreToCustomerDistanceKm(orderId);

  if (distanceKm == null) {
    return { waitMs: baseWaitMs, distanceKm: null };
  }

  if (distanceKm > EDGE_ZONE_BATCH_SKIP_KM) {
    logger.info('batch_wait_skipped', {
      orderId: Number(orderId),
      distanceKm: Number(distanceKm.toFixed(2)),
      thresholdKm: EDGE_ZONE_BATCH_SKIP_KM,
    });
    return { waitMs: 0, distanceKm };
  }

  return { waitMs: baseWaitMs, distanceKm };
}

/**
 * If another batch window is open nearby, attach this order and skip a separate assign.
 * @returns {Promise<{ anchorOrderId: number, status: string } | null>}
 */
async function tryJoinBatchWindow(orderId) {
  const storeDistanceKm = await getStoreToCustomerDistanceKm(orderId);
  if (
    storeDistanceKm != null &&
    storeDistanceKm > EDGE_ZONE_BATCH_SKIP_KM
  ) {
    return null;
  }

  const coords = await getOrderCoords(orderId);
  if (!coords) return null;

  const numericOrderId = Number(orderId);

  for (const [anchorId, window] of pendingBatchWindows) {
    if (Number(anchorId) === numericOrderId) {
      return { anchorOrderId: Number(anchorId), status: 'already_scheduled' };
    }
    if (window.orderIds.has(numericOrderId)) {
      return { anchorOrderId: Number(anchorId), status: 'already_in_window' };
    }
    if (window.orderIds.size >= MAX_BATCH_SIZE) continue;

    const dist = haversineKm(coords.lat, coords.lng, window.lat, window.lng);
    if (dist <= BATCH_RADIUS_KM) {
      window.orderIds.add(numericOrderId);
      logger.info('order_joined_batch_window', {
        orderId: numericOrderId,
        anchorOrderId: Number(anchorId),
        batchSize: window.orderIds.size,
      });
      return { anchorOrderId: Number(anchorId), status: 'joined' };
    }
  }

  return null;
}

/**
 * Find nearby unassigned orders to deliver together with the triggering order.
 * @param {number} riderId
 * @param {number} newOrderId
 * @returns {Promise<number[]>}
 */
async function getBatchForRider(riderId, newOrderId) {
  void riderId;

  const coords = await getOrderCoords(newOrderId);
  if (!coords) {
    return [Number(newOrderId)];
  }

  const { lat: newLat, lng: newLng } = coords;

  const nearbyOrders = await query(
    `SELECT o.id,
       (o.address->>'lat')::numeric AS lat,
       (o.address->>'lng')::numeric AS lng
     FROM orders o
     LEFT JOIN order_assignments oa ON oa.order_id = o.id
       AND oa.status = ANY($2::assignment_status[])
     WHERE o.status = ANY($3::order_status[])
       AND oa.id IS NULL
       AND o.id != $1
       AND o.created_at > NOW() - INTERVAL '10 minutes'
       AND (o.address->>'lat') IS NOT NULL
       AND (o.address->>'lng') IS NOT NULL`,
    [newOrderId, activeAssignmentStatuses, assignableOrderStatuses]
  );

  const batchOrders = [Number(newOrderId)];

  for (const order of nearbyOrders.rows) {
    if (batchOrders.length >= MAX_BATCH_SIZE) break;

    const dist = haversineKm(newLat, newLng, Number(order.lat), Number(order.lng));
    if (dist <= BATCH_RADIUS_KM) {
      batchOrders.push(Number(order.id));
    }
  }

  if (batchOrders.length > 1) {
    logger.info('order_batch_formed', {
      triggerOrderId: Number(newOrderId),
      batchOrderIds: batchOrders,
      batchSize: batchOrders.length,
      radiusKm: BATCH_RADIUS_KM,
    });
  }

  return batchOrders;
}

async function fetchOrdersForBatch(orderIds) {
  if (!orderIds.length) return [];
  const { rows } = await query(
    `SELECT id, customer_id, total_amount, payment_mode, address
     FROM orders
     WHERE id = ANY($1::bigint[])`,
    [orderIds]
  );
  return rows;
}

function buildBatchSocketPayload(assignedOrderIds, orders) {
  const primary =
    orders.find((row) => Number(row.id) === Number(assignedOrderIds[0])) || orders[0];
  const addressText = addressToText(primary?.address);
  const timeoutMs = Number(process.env.ASSIGNMENT_TIMEOUT_MS || 10_000);
  const totalAmount =
    primary?.total_amount != null ? Number(primary.total_amount) : undefined;

  return {
    orderIds: assignedOrderIds,
    orderId: assignedOrderIds[0],
    isBatch: assignedOrderIds.length > 1,
    batchCount: assignedOrderIds.length,
    message:
      assignedOrderIds.length > 1
        ? `${assignedOrderIds.length} nearby orders — deliver together!`
        : 'New order for you!',
    expiresIn: Math.ceil(timeoutMs / 1000),
    timeout: timeoutMs,
    totalAmount,
    amount: totalAmount,
    total_amount: totalAmount,
    total_price: totalAmount,
    address: addressText,
    customerAddress: addressText,
    delivery_address: addressText,
    paymentMode: primary?.payment_mode,
    batchOrders: orders.map((row) => ({
      orderId: Number(row.id),
      totalAmount: row.total_amount != null ? Number(row.total_amount) : undefined,
      address: addressToText(row.address),
    })),
    timestamp: new Date().toISOString(),
  };
}

/**
 * Persist batch assignments and notify rider + customers.
 * @returns {Promise<number[]>}
 */
async function assignBatchToRider(riderId, riderUserId, orderIds, io) {
  const normalizedIds = [...new Set(orderIds.map(Number))].slice(0, MAX_BATCH_SIZE);
  const batchJson = JSON.stringify(normalizedIds);
  const assignedOrderIds = [];

  for (const orderId of normalizedIds) {
    const { rowCount } = await query(
      `INSERT INTO order_assignments
         (order_id, delivery_partner_id, status, assigned_at, batch_ids)
       VALUES ($1, $2, 'ASSIGNED', NOW(), $3::jsonb)
       ON CONFLICT (order_id) DO NOTHING`,
      [orderId, riderId, batchJson]
    );
    if (rowCount > 0) {
      assignedOrderIds.push(Number(orderId));
    }
  }

  if (!assignedOrderIds.length) {
    return assignedOrderIds;
  }

  const orders = await fetchOrdersForBatch(assignedOrderIds);
  const payload = buildBatchSocketPayload(assignedOrderIds, orders);

  if (io && riderUserId) {
    const riderUserIdNum = Number(riderUserId);
    io.to(`user:${riderUserIdNum}`).emit('order:assigned', payload);
    io.to(`delivery_${riderUserIdNum}`).emit('order:assigned', payload);
  }

  for (const orderId of assignedOrderIds) {
    const order = orders.find((row) => Number(row.id) === Number(orderId));
    if (order?.customer_id && io) {
      io.to(`customer_${Number(order.customer_id)}`).emit('order:partner_assigned', {
        orderId: Number(orderId),
      });
    }
  }

  logger.info('order_batch_assigned', {
    riderId,
    riderUserId,
    orderIds: assignedOrderIds,
    batchSize: assignedOrderIds.length,
  });

  return assignedOrderIds;
}

async function finalizeBatchWindow(anchorOrderId, onAssigned) {
  const window = pendingBatchWindows.get(Number(anchorOrderId));
  if (!window) return [];

  pendingBatchWindows.delete(Number(anchorOrderId));
  clearTimeout(window.timer);

  try {
    const scanned = await getBatchForRider(window.riderId, anchorOrderId);
    const merged = [...window.orderIds];
    for (const id of scanned) {
      if (!merged.includes(id) && merged.length < MAX_BATCH_SIZE) {
        merged.push(id);
      }
    }

    const assigned = await assignBatchToRider(
      window.riderId,
      window.riderUserId,
      merged,
      window.io
    );
    if (onAssigned) {
      onAssigned(assigned);
    }
    return assigned;
  } catch (err) {
    logger.error('batch_window_finalize_failed', {
      anchorOrderId,
      error: err.message,
    });
    return [];
  }
}

/**
 * Wait for nearby orders, then assign the batch.
 * @param {{ triggerOrderId: number, riderId: number, riderUserId: number, io: any, onAssigned?: (ids: number[]) => void }} params
 */
async function scheduleBatchAssignment({
  triggerOrderId,
  riderId,
  riderUserId,
  io,
  onAssigned,
}) {
  const { waitMs } = await resolveEffectiveBatchWaitMs(triggerOrderId);
  const coords = await getOrderCoords(triggerOrderId);
  const numericTriggerId = Number(triggerOrderId);

  if (!coords || waitMs <= 0) {
    const batchOrderIds = await getBatchForRider(riderId, numericTriggerId);
    const assigned = await assignBatchToRider(riderId, riderUserId, batchOrderIds, io);
    if (onAssigned) onAssigned(assigned);
    return { immediate: true, assignedOrderIds: assigned };
  }

  if (pendingBatchWindows.has(numericTriggerId)) {
    return { deferred: true, anchorOrderId: numericTriggerId, waitMs };
  }

  for (const [anchorId, window] of pendingBatchWindows) {
    if (Number(window.riderId) !== Number(riderId)) continue;
    if (window.orderIds.size >= MAX_BATCH_SIZE) continue;
    const dist = haversineKm(coords.lat, coords.lng, window.lat, window.lng);
    if (dist <= BATCH_RADIUS_KM) {
      window.orderIds.add(numericTriggerId);
      return { deferred: true, anchorOrderId: Number(anchorId), waitMs, joined: true };
    }
  }

  const timer = setTimeout(() => {
    finalizeBatchWindow(numericTriggerId, onAssigned).catch((err) => {
      logger.error('batch_window_timer_failed', {
        anchorOrderId: numericTriggerId,
        error: err.message,
      });
    });
  }, waitMs);

  pendingBatchWindows.set(numericTriggerId, {
    riderId: Number(riderId),
    riderUserId: Number(riderUserId),
    io,
    lat: coords.lat,
    lng: coords.lng,
    orderIds: new Set([numericTriggerId]),
    timer,
  });

  logger.info('batch_window_scheduled', {
    triggerOrderId: numericTriggerId,
    riderId,
    waitMs,
  });

  return { deferred: true, anchorOrderId: numericTriggerId, waitMs };
}

module.exports = {
  getBatchForRider,
  assignBatchToRider,
  tryJoinBatchWindow,
  scheduleBatchAssignment,
  getStoreToCustomerDistanceKm,
  BATCH_RADIUS_KM,
  MAX_BATCH_SIZE,
  BATCH_WAIT_MS,
  EDGE_ZONE_BATCH_SKIP_KM,
};
