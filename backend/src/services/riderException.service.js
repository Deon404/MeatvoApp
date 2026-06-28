const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { getDeliveryPartnerIdForUser } = require('../utils/deliveryPartner.util');
const {
  publishOperationalEventAsync,
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
} = require('../utils/operationalEvents.util');
const { sendNotification } = require('./notification.service');
const { ROLES } = require('../utils/roles');
const {
  RIDER_EXCEPTION_TYPE_SET,
  RIDER_EXCEPTION_LABELS,
  EXCEPTION_TO_OPERATIONAL_STATUS,
  RIDER_EXCEPTION_ELIGIBLE_STATUSES,
  RIDER_OPERATIONAL_STATUS,
} = require('../constants/riderException.constants');

async function reportRiderOperationalException({
  orderId,
  riderUserId,
  exceptionType,
  notes = null,
  io = null,
}) {
  const normalizedType = String(exceptionType || '').trim().toUpperCase();
  if (!RIDER_EXCEPTION_TYPE_SET.has(normalizedType)) {
    const err = new Error('Invalid operational exception type');
    err.statusCode = 400;
    throw err;
  }

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(riderUserId);
  if (!deliveryPartnerId) {
    const err = new Error('Delivery partner profile not found');
    err.statusCode = 400;
    throw err;
  }

  const { rows: orderRows } = await query(
    `SELECT o.id, o.status, o.customer_id, oa.delivery_partner_id
     FROM orders o
     JOIN order_assignments oa ON oa.order_id = o.id
     WHERE o.id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) {
    const err = new Error('Order not found');
    err.statusCode = 404;
    throw err;
  }
  if (Number(order.delivery_partner_id) !== Number(deliveryPartnerId)) {
    const err = new Error('Order not assigned to you');
    err.statusCode = 403;
    throw err;
  }
  if (!RIDER_EXCEPTION_ELIGIBLE_STATUSES.has(String(order.status || '').toUpperCase())) {
    const err = new Error('Operational exceptions are only allowed during active delivery');
    err.statusCode = 400;
    throw err;
  }

  const operationalStatus =
    EXCEPTION_TO_OPERATIONAL_STATUS[normalizedType] || RIDER_OPERATIONAL_STATUS.NORMAL;

  await query(
    `UPDATE delivery_partners
     SET operational_status = $1, updated_at = NOW()
     WHERE id = $2`,
    [operationalStatus, deliveryPartnerId]
  );

  const label = RIDER_EXCEPTION_LABELS[normalizedType] || normalizedType;
  const payload = {
    exceptionType: normalizedType,
    label,
    notes: notes || null,
    operationalStatus,
  };

  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.OPERATIONAL_EXCEPTION,
    orderId,
    actorType: ACTOR_TYPES.RIDER,
    actorId: riderUserId,
    riderId: deliveryPartnerId,
    previousState: String(order.status || '').toUpperCase(),
    newState: String(order.status || '').toUpperCase(),
    metadata: payload,
  });

  if (io) {
    io.to('admin_room').emit('rider:operational_exception', {
      orderId: Number(orderId),
      riderUserId: Number(riderUserId),
      exceptionType: normalizedType,
      label,
      operationalStatus,
      notes: notes || null,
      timestamp: new Date().toISOString(),
    });
  }

  try {
    await sendNotification({
      role: ROLES.ADMIN,
      title: `Rider needs help: ${label}`,
      body: `Order #${orderId} — rider reported ${label.toLowerCase()}`,
      data: {
        type: 'rider_exception',
        orderId: String(orderId),
        exceptionType: normalizedType,
      },
      io,
    });
  } catch (notifyErr) {
    logger.warn('rider_exception_notify_failed', { orderId, error: notifyErr.message });
  }

  logger.info('rider_operational_exception', {
    orderId,
    riderUserId,
    exceptionType: normalizedType,
    operationalStatus,
  });

  return {
    orderId: Number(orderId),
    exceptionType: normalizedType,
    label,
    operationalStatus,
  };
}

module.exports = {
  reportRiderOperationalException,
};
