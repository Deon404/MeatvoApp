const { query } = require('../db/postgres');
const { logger } = require('./logger');
const {
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
  EVENT_TIMESTAMP_COLUMNS,
  EVENT_DESCRIPTIONS,
  STATE_TRANSITION_EVENT_MAP,
  resolveActorType,
} = require('../constants/operationalEvent.constants');

const ALLOWED_TIMESTAMP_COLUMNS = new Set(Object.values(EVENT_TIMESTAMP_COLUMNS));

function buildStandardPayload({
  eventType,
  orderId = null,
  actorType = ACTOR_TYPES.SYSTEM,
  actorId = null,
  previousState = null,
  newState = null,
  metadata = {},
  timestamp = new Date().toISOString(),
}) {
  return {
    eventType,
    orderId: orderId != null ? Number(orderId) : null,
    actorType,
    actorId: actorId != null ? Number(actorId) : null,
    previousState,
    newState,
    timestamp,
    metadata,
    description: EVENT_DESCRIPTIONS[eventType] || eventType,
  };
}

/**
 * Persist operational event. Never throws — failures are logged only.
 */
async function recordOperationalEvent({
  eventType,
  orderId = null,
  actorId = null,
  riderId = null,
  payload = {},
}) {
  try {
    const { rows } = await query(
      `INSERT INTO operational_events (event_type, order_id, actor_id, rider_id, payload)
       VALUES ($1, $2, $3, $4, $5::jsonb)
       RETURNING id, event_type, order_id, actor_id, rider_id, payload, created_at`,
      [
        eventType,
        orderId,
        actorId,
        riderId,
        JSON.stringify(payload),
      ]
    );
    return rows[0];
  } catch (err) {
    logger.warn('operational_event_persist_failed', {
      eventType,
      orderId,
      error: err.message,
    });
    return null;
  }
}

/**
 * Stamp order lifecycle timestamp once (COALESCE — never overwrite).
 */
async function stampOrderTimestamp(orderId, column, at = new Date()) {
  if (!orderId || !column || !ALLOWED_TIMESTAMP_COLUMNS.has(column)) return;
  try {
    await query(
      `UPDATE orders
       SET ${column} = COALESCE(${column}, $1::timestamptz),
           updated_at = NOW()
       WHERE id = $2`,
      [at.toISOString(), orderId]
    );
  } catch (err) {
    logger.warn('operational_timestamp_stamp_failed', {
      orderId,
      column,
      error: err.message,
    });
  }
}

async function stampTimestampForEvent(orderId, eventType, at = new Date()) {
  const column = EVENT_TIMESTAMP_COLUMNS[eventType];
  if (!column) return;
  await stampOrderTimestamp(orderId, column, at);
}

function emitOperationalEvent(io, { eventType, orderId, payload = {} }) {
  if (!io) return;
  const envelope = {
    type: eventType,
    orderId: orderId != null ? Number(orderId) : null,
    payload,
    timestamp: payload.timestamp || new Date().toISOString(),
  };
  io.to('admin_room').emit('operational:event', envelope);
  io.to('staff_room').emit('operational:event', envelope);
  io.to('admin:orders').emit('operational:event', envelope);
  io.to('staff:orders').emit('operational:event', envelope);
}

async function publishOperationalEvent(io, params) {
  const timestamp = params.timestamp || new Date().toISOString();
  const actorType = params.actorType || ACTOR_TYPES.SYSTEM;
  const payload = buildStandardPayload({
    eventType: params.eventType,
    orderId: params.orderId,
    actorType,
    actorId: params.actorId,
    previousState: params.previousState ?? null,
    newState: params.newState ?? null,
    metadata: params.metadata || {},
    timestamp,
  });

  const row = await recordOperationalEvent({
    eventType: params.eventType,
    orderId: params.orderId,
    actorId: params.actorId,
    riderId: params.riderId ?? params.metadata?.riderId ?? null,
    payload,
  });

  if (params.orderId && params.stampTimestamp !== false) {
    await stampTimestampForEvent(params.orderId, params.eventType, new Date(timestamp));
  }

  emitOperationalEvent(io, {
    eventType: params.eventType,
    orderId: params.orderId,
    payload: { ...payload, eventId: row?.id ?? null },
  });

  return row;
}

/**
 * Fire-and-forget instrumentation — must not block or fail business transactions.
 */
function publishOperationalEventAsync(io, params) {
  setImmediate(() => {
    publishOperationalEvent(io, params).catch((err) => {
      logger.warn('operational_event_async_failed', {
        eventType: params?.eventType,
        orderId: params?.orderId,
        error: err.message,
      });
    });
  });
}

/**
 * Instrument an order state transition with a single lifecycle event.
 */
function instrumentOrderStateTransition(io, {
  orderId,
  previousState,
  newState,
  actor,
  actorRole,
  metadata = {},
}) {
  const eventType = STATE_TRANSITION_EVENT_MAP[newState];
  if (!eventType) return;

  publishOperationalEventAsync(io, {
    eventType,
    orderId,
    actorType: resolveActorType(actorRole),
    actorId: actor,
    previousState,
    newState,
    metadata,
  });

  if (newState === 'PACKED') {
    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.ENTERED_DISPATCH_QUEUE,
      orderId,
      actorType: resolveActorType(actorRole),
      actorId: actor,
      previousState,
      newState,
      metadata: { ...metadata, dispatchQueued: true },
    });
  }
}

/**
 * Instrument order confirmation (payment or COD) without a state-machine transition.
 */
function instrumentOrderConfirmed(io, { orderId, actorId = null, actorRole = 'system', metadata = {} }) {
  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.ORDER_CONFIRMED,
    orderId,
    actorType: resolveActorType(actorRole),
    actorId,
    previousState: 'PLACED',
    newState: 'CONFIRMED',
    metadata,
  });
}

function instrumentRiderAssigned(io, {
  orderId,
  riderId,
  riderUserId = null,
  assignmentAttempt = null,
  assignmentSuccess = true,
  assignmentFailureReason = null,
  batchId = null,
  batchSize = null,
  metadata = {},
}) {
  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.RIDER_ASSIGNED,
    orderId,
    actorType: ACTOR_TYPES.SYSTEM,
    riderId,
    previousState: 'PACKED',
    newState: 'PACKED',
    metadata: {
      riderId,
      riderUserId,
      assignmentAttempts: assignmentAttempt,
      assignmentSuccess,
      assignmentFailureReason,
      batchId,
      batchSize,
      ...metadata,
    },
  });
}

function instrumentRiderAcceptedAndDispatched(io, {
  orderId,
  riderId,
  riderUserId,
  previousState = 'PACKED',
  metadata = {},
}) {
  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.RIDER_ACCEPTED,
    orderId,
    actorType: ACTOR_TYPES.RIDER,
    actorId: riderUserId,
    riderId,
    previousState,
    newState: 'OUT_FOR_DELIVERY',
    metadata: { riderId, riderUserId, ...metadata },
  });
  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.OUT_FOR_DELIVERY,
    orderId,
    actorType: ACTOR_TYPES.RIDER,
    actorId: riderUserId,
    riderId,
    previousState,
    newState: 'OUT_FOR_DELIVERY',
    metadata: { riderId, riderUserId, ...metadata },
  });
}

function instrumentBatchCreated(io, {
  orderIds,
  anchorOrderId,
  batchId,
  batchSize,
  riderId = null,
}) {
  for (const orderId of orderIds) {
    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.BATCH_CREATED,
      orderId,
      actorType: ACTOR_TYPES.SYSTEM,
      riderId,
      metadata: {
        batchId,
        batchSize,
        anchorOrderId,
        orderIds,
      },
    });
  }
}

module.exports = {
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
  resolveActorType,
  buildStandardPayload,
  recordOperationalEvent,
  stampOrderTimestamp,
  stampTimestampForEvent,
  emitOperationalEvent,
  publishOperationalEvent,
  publishOperationalEventAsync,
  instrumentOrderStateTransition,
  instrumentOrderConfirmed,
  instrumentRiderAssigned,
  instrumentRiderAcceptedAndDispatched,
  instrumentBatchCreated,
};
