const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const {
  EVENT_DESCRIPTIONS,
  ACTOR_TYPES,
} = require('../constants/operationalEvent.constants');

function formatTimelineEntry(row) {
  const payload = row.payload && typeof row.payload === 'object' ? row.payload : {};
  const actorType = payload.actorType || ACTOR_TYPES.SYSTEM;
  const actorId = payload.actorId ?? row.actor_id ?? null;
  const timestamp = payload.timestamp || row.created_at;

  return {
    id: Number(row.id),
    eventType: row.event_type,
    orderId: row.order_id != null ? Number(row.order_id) : null,
    actorType,
    actorId: actorId != null ? Number(actorId) : null,
    previousState: payload.previousState ?? null,
    newState: payload.newState ?? null,
    timestamp: timestamp ? new Date(timestamp).toISOString() : null,
    description: payload.description || EVENT_DESCRIPTIONS[row.event_type] || row.event_type,
    metadata: payload.metadata || {},
    riderId: row.rider_id != null ? Number(row.rider_id) : payload.metadata?.riderId ?? null,
  };
}

async function listOperationalEvents({
  orderId = null,
  riderId = null,
  eventType = null,
  fromDate = null,
  toDate = null,
  limit = 50,
  offset = 0,
} = {}) {
  const params = [];
  const conditions = [];

  if (orderId != null) {
    params.push(Number(orderId));
    conditions.push(`order_id = $${params.length}`);
  }
  if (riderId != null) {
    params.push(Number(riderId));
    conditions.push(
      `(rider_id = $${params.length} OR (payload->'metadata'->>'riderId')::bigint = $${params.length})`
    );
  }
  if (eventType) {
    params.push(String(eventType).toUpperCase());
    conditions.push(`event_type = $${params.length}`);
  }
  if (fromDate) {
    params.push(new Date(fromDate).toISOString());
    conditions.push(`created_at >= $${params.length}::timestamptz`);
  }
  if (toDate) {
    params.push(new Date(toDate).toISOString());
    conditions.push(`created_at <= $${params.length}::timestamptz`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 200);
  const safeOffset = Math.max(Number(offset) || 0, 0);

  params.push(safeLimit);
  const limitPh = `$${params.length}`;
  params.push(safeOffset);
  const offsetPh = `$${params.length}`;

  const { rows } = await query(
    `SELECT id, event_type, order_id, actor_id, rider_id, payload, created_at
     FROM operational_events
     ${where}
     ORDER BY created_at DESC
     LIMIT ${limitPh} OFFSET ${offsetPh}`,
    params
  );

  return rows.map(formatTimelineEntry);
}

async function getOrderOperationalTimeline(orderId) {
  const numericId = Number(orderId);
  if (!Number.isFinite(numericId) || numericId <= 0) {
    const err = new Error('Invalid order id');
    err.statusCode = 400;
    throw err;
  }

  const { rows: orderRows } = await query(
    `SELECT id FROM orders WHERE id = $1`,
    [numericId]
  );
  if (!orderRows[0]) {
    const err = new Error('Order not found');
    err.statusCode = 404;
    throw err;
  }

  const { rows } = await query(
    `SELECT id, event_type, order_id, actor_id, rider_id, payload, created_at
     FROM operational_events
     WHERE order_id = $1
     ORDER BY created_at DESC`,
    [numericId]
  );

  return {
    orderId: numericId,
    events: rows.map(formatTimelineEntry),
    count: rows.length,
  };
}

async function hasOperationalEvent(orderId, eventType) {
  const { rows } = await query(
    `SELECT 1 FROM operational_events
     WHERE order_id = $1 AND event_type = $2
     LIMIT 1`,
    [orderId, eventType]
  );
  return Boolean(rows[0]);
}

async function recordDeliveryBatch({
  anchorOrderId,
  orderIds,
  batchSize,
}) {
  try {
    const { rows } = await query(
      `INSERT INTO delivery_batches (anchor_order_id, batch_size, order_ids)
       VALUES ($1, $2, $3::jsonb)
       RETURNING id, anchor_order_id, batch_size, order_ids, created_at`,
      [anchorOrderId, batchSize, JSON.stringify(orderIds)]
    );
    return rows[0];
  } catch (err) {
    logger.warn('delivery_batch_record_failed', {
      anchorOrderId,
      error: err.message,
    });
    return null;
  }
}

async function monitorPeakKitchenQueue(io) {
  const { OPERATIONS } = require('../config/businessRules');
  const redis = require('../db/redis');
  const { publishOperationalEventAsync, OPERATIONAL_EVENT_TYPES, ACTOR_TYPES } = require('../utils/operationalEvents.util');

  try {
    const { rows } = await query(
      `SELECT COUNT(*)::int AS count
       FROM orders
       WHERE status IN ('CONFIRMED', 'PACKING_STARTED', 'PACKED')`
    );
    const queueDepth = Number(rows[0]?.count || 0);
    if (queueDepth < OPERATIONS.peakQueueThreshold) {
      return { queueDepth, alertEmitted: false };
    }

    const key = 'ops:peak_alert';
    const set = await redis.set(
      key,
      String(queueDepth),
      'EX',
      OPERATIONS.peakAlertCooldownSeconds,
      'NX'
    );
    if (set !== 'OK') {
      return { queueDepth, alertEmitted: false, deduped: true };
    }

    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.PEAK_ALERT_TRIGGERED,
      orderId: null,
      actorType: ACTOR_TYPES.SYSTEM,
      metadata: { queueDepth, threshold: OPERATIONS.peakQueueThreshold },
    });

    if (io) {
      io.to('admin_room').emit('store:peak_alert', {
        queueDepth,
        threshold: OPERATIONS.peakQueueThreshold,
        timestamp: new Date().toISOString(),
      });
    }

    return { queueDepth, alertEmitted: true };
  } catch (err) {
    logger.warn('peak_queue_monitor_failed', { error: err.message });
    return { queueDepth: 0, alertEmitted: false, error: err.message };
  }
}

module.exports = {
  listOperationalEvents,
  getOrderOperationalTimeline,
  hasOperationalEvent,
  recordDeliveryBatch,
  monitorPeakKitchenQueue,
  formatTimelineEntry,
};
