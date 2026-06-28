const { withTransaction, query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { canTransition, DELIVERY_STATUS_TRANSITIONS } = require('../utils/orderStatus');
const { restoreStockForOrder } = require('../modules/payments/payment-stock');
const { getDeliveryPartnerIdForUser, refreshPartnerOperationalState } = require('../utils/deliveryPartner.util');
const { sendNotification } = require('./notification.service');
const { ROLES } = require('../utils/roles');
const {
  publishOperationalEventAsync,
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
  resolveActorType,
} = require('../utils/operationalEvents.util');
const {
  FAILED_DELIVERY_REASONS,
  FAILED_DELIVERY_REASON_LABELS,
  RETURN_CONDITIONS,
  RETURN_CONDITION_LABELS,
  FAILED_DELIVERY_RESOLUTIONS,
  ADMIN_TASK_TYPES,
  ADMIN_TASK_STATUS,
  RIDER_FAILABLE_ORDER_STATUSES,
  isOrderBlockedFromAssignment,
} = require('../constants/failedDelivery.constants');

const FAILED_REASON_SET = new Set(Object.values(FAILED_DELIVERY_REASONS));
const RETURN_CONDITION_SET = new Set(Object.values(RETURN_CONDITIONS));
const RESOLUTION_SET = new Set([
  FAILED_DELIVERY_RESOLUTIONS.REDELIVER,
  FAILED_DELIVERY_RESOLUTIONS.REFUND,
  FAILED_DELIVERY_RESOLUTIONS.DISCARD,
]);

async function createAdminTask(client, { taskType, orderId, payload = {} }) {
  const db = client || { query };
  const { rows } = await db.query(
    `INSERT INTO admin_tasks (task_type, order_id, status, payload)
     VALUES ($1, $2, $3, $4)
     RETURNING id, task_type, order_id, status, payload, created_at`,
    [taskType, orderId, ADMIN_TASK_STATUS.OPEN, JSON.stringify(payload)]
  );
  return rows[0];
}

async function resolveAdminTask(client, { orderId, taskType, adminUserId }) {
  const db = client || { query };
  await db.query(
    `UPDATE admin_tasks
     SET status = $1, resolved_at = NOW(), resolved_by = $2
     WHERE order_id = $3 AND task_type = $4 AND status = $5`,
    [
      ADMIN_TASK_STATUS.RESOLVED,
      adminUserId,
      orderId,
      taskType,
      ADMIN_TASK_STATUS.OPEN,
    ]
  );
}

async function listOpenAdminTasks({ taskType = null } = {}) {
  const params = [ADMIN_TASK_STATUS.OPEN];
  let sql = `
    SELECT t.id, t.task_type, t.order_id, t.status, t.payload, t.created_at,
           o.status AS order_status, o.failed_delivery_reason, o.failed_delivery_resolution,
           o.returned_at, o.return_condition, o.total_amount,
           u.name AS customer_name, u.phone AS customer_phone
    FROM admin_tasks t
    JOIN orders o ON o.id = t.order_id
    JOIN users u ON u.id = o.customer_id
    WHERE t.status = $1`;
  if (taskType) {
    params.push(taskType);
    sql += ` AND t.task_type = $${params.length}`;
  }
  sql += ' ORDER BY t.created_at ASC';
  const { rows } = await query(sql, params);
  return rows;
}

function emitFailedDeliveryAdminAlert(io, payload) {
  if (!io) return;
  io.to('admin_room').emit('order:failed_delivery', payload);
  io.to('admin_room').emit('order:updated', {
    orderId: payload.orderId,
    status: 'FAILED_DELIVERY',
    updatedAt: new Date().toISOString(),
    failedDelivery: payload,
  });
}

function emitReturnToStoreAdminAlert(io, payload) {
  if (!io) return;
  io.to('admin_room').emit('order:returned_to_store', payload);
  io.to('admin_room').emit('order:updated', {
    orderId: payload.orderId,
    status: 'FAILED_DELIVERY',
    updatedAt: new Date().toISOString(),
    returnedToStore: true,
  });
}

async function markFailedDelivery({ orderId, riderUserId, reason, io = null }) {
  const normalizedReason = String(reason || '').trim().toUpperCase();
  if (!FAILED_REASON_SET.has(normalizedReason)) {
    const err = new Error('Invalid failed delivery reason');
    err.statusCode = 400;
    throw err;
  }

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(riderUserId);
  if (!deliveryPartnerId) {
    const err = new Error('Delivery partner profile not found');
    err.statusCode = 400;
    throw err;
  }

  const result = await withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      `SELECT id, customer_id, status, payment_mode, payment_status,
              failed_delivery_resolution, returned_at
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId]
    );
    const order = orderRows[0];
    if (!order) {
      const err = new Error('Order not found');
      err.statusCode = 404;
      throw err;
    }

    if (isOrderBlockedFromAssignment(order)) {
      const err = new Error('Order already marked as failed delivery');
      err.statusCode = 409;
      throw err;
    }

    if (!RIDER_FAILABLE_ORDER_STATUSES.has(String(order.status || '').toUpperCase())) {
      const err = new Error(`Cannot mark failed delivery from status ${order.status}`);
      err.statusCode = 400;
      throw err;
    }

    const { rows: assignmentRows } = await client.query(
      `SELECT id, status FROM order_assignments
       WHERE order_id = $1 AND delivery_partner_id = $2 FOR UPDATE`,
      [orderId, deliveryPartnerId]
    );
    if (!assignmentRows[0]) {
      const err = new Error('Order not assigned to you');
      err.statusCode = 403;
      throw err;
    }

    if (!canTransition(DELIVERY_STATUS_TRANSITIONS, order.status, 'FAILED_DELIVERY')) {
      const err = new Error(`Invalid transition from ${order.status} to FAILED_DELIVERY`);
      err.statusCode = 400;
      throw err;
    }

    await client.query(
      `UPDATE orders SET
         status = 'FAILED_DELIVERY',
         failed_delivery_reason = $1,
         failed_delivery_at = NOW(),
         failed_delivery_by = $2,
         failed_delivery_resolution = $3,
         updated_at = NOW()
       WHERE id = $4`,
      [
        normalizedReason,
        riderUserId,
        FAILED_DELIVERY_RESOLUTIONS.PENDING,
        orderId,
      ]
    );

    await client.query(
      `UPDATE order_assignments SET status = 'FAILED', updated_at = NOW() WHERE order_id = $1`,
      [orderId]
    );

    const task = await createAdminTask(client, {
      taskType: ADMIN_TASK_TYPES.FAILED_DELIVERY,
      orderId,
      payload: {
        reason: normalizedReason,
        reasonLabel: FAILED_DELIVERY_REASON_LABELS[normalizedReason],
        riderUserId,
        deliveryPartnerId,
        awaitingReturn: true,
      },
    });

    const { rows: updatedRows } = await client.query(
      `SELECT id, customer_id, status, total_amount, payment_mode, payment_status,
              failed_delivery_reason, failed_delivery_at, failed_delivery_by,
              failed_delivery_resolution
       FROM orders WHERE id = $1`,
      [orderId]
    );

    return { order: updatedRows[0], task, customerId: order.customer_id };
  });

  const { clearAssignmentTimeout } = require('./assignment.service');
  clearAssignmentTimeout(orderId);

  const reasonLabel = FAILED_DELIVERY_REASON_LABELS[normalizedReason];
  const adminPayload = {
    orderId,
    reason: normalizedReason,
    reasonLabel,
    riderUserId,
    taskId: result.task?.id,
    resolution: FAILED_DELIVERY_RESOLUTIONS.PENDING,
    timestamp: new Date().toISOString(),
  };
  emitFailedDeliveryAdminAlert(io, adminPayload);

  await sendNotification({
    userId: result.customerId,
    role: ROLES.CUSTOMER,
    type: 'delivery_attempted',
    title: 'Delivery attempted',
    body: `We tried to deliver your order but could not complete it (${reasonLabel}). Our team will contact you shortly.`,
    data: { orderId, reason: normalizedReason, customerStatus: 'DELIVERY_ATTEMPTED' },
    priority: 'high',
    channels: ['socket', 'push'],
    io,
  });

  logger.info('failed_delivery_marked', {
    orderId,
    riderUserId,
    reason: normalizedReason,
  });

  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.DELIVERY_ATTEMPTED,
    orderId,
    actorType: ACTOR_TYPES.RIDER,
    actorId: riderUserId,
    riderId: deliveryPartnerId,
    previousState: result.order?.status || 'OUT_FOR_DELIVERY',
    newState: 'FAILED_DELIVERY',
    metadata: {
      failureReason: normalizedReason,
      reasonLabel,
    },
  });

  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.FAILED_DELIVERY,
    orderId,
    actorType: ACTOR_TYPES.RIDER,
    actorId: riderUserId,
    riderId: deliveryPartnerId,
    previousState: 'OUT_FOR_DELIVERY',
    newState: 'FAILED_DELIVERY',
    metadata: {
      failureReason: normalizedReason,
      reasonLabel,
    },
  });

  refreshPartnerOperationalState({
    deliveryPartnerId,
    io,
    reason: 'failed_delivery',
  }).catch(() => {});

  return result;
}

async function confirmReturnToStore({ orderId, riderUserId, returnCondition, io = null }) {
  const normalizedCondition = String(returnCondition || '').trim().toUpperCase();
  if (!RETURN_CONDITION_SET.has(normalizedCondition)) {
    const err = new Error('Invalid return condition');
    err.statusCode = 400;
    throw err;
  }

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(riderUserId);
  if (!deliveryPartnerId) {
    const err = new Error('Delivery partner profile not found');
    err.statusCode = 400;
    throw err;
  }

  const result = await withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      `SELECT id, customer_id, status, failed_delivery_reason, failed_delivery_resolution,
              failed_delivery_by, returned_at
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId]
    );
    const order = orderRows[0];
    if (!order) {
      const err = new Error('Order not found');
      err.statusCode = 404;
      throw err;
    }

    if (String(order.status).toUpperCase() !== 'FAILED_DELIVERY') {
      const err = new Error('Order is not in failed delivery state');
      err.statusCode = 400;
      throw err;
    }

    if (String(order.failed_delivery_resolution).toUpperCase() !== FAILED_DELIVERY_RESOLUTIONS.PENDING) {
      const err = new Error('Failed delivery already resolved by admin');
      err.statusCode = 409;
      throw err;
    }

    if (order.returned_at) {
      const err = new Error('Return to store already confirmed');
      err.statusCode = 409;
      throw err;
    }

    const { rows: assignmentRows } = await client.query(
      `SELECT id FROM order_assignments
       WHERE order_id = $1 AND delivery_partner_id = $2`,
      [orderId, deliveryPartnerId]
    );
    if (!assignmentRows[0]) {
      const err = new Error('Order not assigned to you');
      err.statusCode = 403;
      throw err;
    }

    const returnReason = order.failed_delivery_reason;

    await client.query(
      `UPDATE orders SET
         returned_at = NOW(),
         returned_by = $1,
         return_reason = $2,
         return_condition = $3,
         updated_at = NOW()
       WHERE id = $4`,
      [riderUserId, returnReason, normalizedCondition, orderId]
    );

    await client.query(
      `UPDATE admin_tasks
       SET payload = payload || $1::jsonb
       WHERE order_id = $2 AND task_type = $3 AND status = $4`,
      [
        JSON.stringify({
          awaitingReturn: false,
          returnCondition: normalizedCondition,
          returnConditionLabel: RETURN_CONDITION_LABELS[normalizedCondition],
          returnedAt: new Date().toISOString(),
          returnedBy: riderUserId,
        }),
        orderId,
        ADMIN_TASK_TYPES.FAILED_DELIVERY,
        ADMIN_TASK_STATUS.OPEN,
      ]
    );

    const { rows: updatedRows } = await client.query(
      `SELECT id, customer_id, status, failed_delivery_reason, failed_delivery_resolution,
              returned_at, returned_by, return_reason, return_condition
       FROM orders WHERE id = $1`,
      [orderId]
    );

    return { order: updatedRows[0] };
  });

  emitReturnToStoreAdminAlert(io, {
    orderId,
    returnCondition: normalizedCondition,
    returnConditionLabel: RETURN_CONDITION_LABELS[normalizedCondition],
    riderUserId,
    timestamp: new Date().toISOString(),
  });

  logger.info('return_to_store_confirmed', {
    orderId,
    riderUserId,
    returnCondition: normalizedCondition,
  });

  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.RETURN_TO_STORE,
    orderId,
    actorType: ACTOR_TYPES.RIDER,
    actorId: riderUserId,
    riderId: deliveryPartnerId,
    previousState: 'FAILED_DELIVERY',
    newState: 'FAILED_DELIVERY',
    metadata: {
      returnCondition: normalizedCondition,
      returnConditionLabel: RETURN_CONDITION_LABELS[normalizedCondition],
    },
  });

  refreshPartnerOperationalState({
    deliveryPartnerId,
    io,
    reason: 'return_to_store',
  }).catch(() => {});

  return result;
}

async function resolveFailedDelivery({ orderId, adminUserId, resolution, io = null }) {
  const normalizedResolution = String(resolution || '').trim().toUpperCase();
  if (!RESOLUTION_SET.has(normalizedResolution)) {
    const err = new Error('Invalid resolution. Use REDELIVER, REFUND, or DISCARD');
    err.statusCode = 400;
    throw err;
  }

  const result = await withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      `SELECT id, customer_id, status, payment_mode, payment_status,
              failed_delivery_resolution, returned_at, return_condition, total_amount
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId]
    );
    const order = orderRows[0];
    if (!order) {
      const err = new Error('Order not found');
      err.statusCode = 404;
      throw err;
    }

    if (String(order.status).toUpperCase() !== 'FAILED_DELIVERY') {
      const err = new Error('Order is not in failed delivery state');
      err.statusCode = 400;
      throw err;
    }

    if (String(order.failed_delivery_resolution).toUpperCase() !== FAILED_DELIVERY_RESOLUTIONS.PENDING) {
      const err = new Error('Failed delivery already resolved');
      err.statusCode = 409;
      throw err;
    }

    if (!order.returned_at) {
      const err = new Error('Rider must confirm return to store before admin resolution');
      err.statusCode = 400;
      throw err;
    }

    let newStatus;
    if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REDELIVER) {
      newStatus = 'PACKED';
    } else if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REFUND) {
      newStatus = 'REFUNDED';
    } else {
      newStatus = 'CANCELLED';
    }

    await client.query(
      `UPDATE orders SET
         status = $1,
         failed_delivery_resolution = $2,
         failed_delivery_resolved_at = NOW(),
         failed_delivery_resolved_by = $3,
         payment_status = CASE
           WHEN $4 = 'REFUND' THEN 'REFUNDED'
           WHEN $4 = 'DISCARD' AND UPPER(payment_mode) = 'ONLINE' THEN 'REFUNDED'
           ELSE payment_status
         END,
         updated_at = NOW()
       WHERE id = $5`,
      [newStatus, normalizedResolution, adminUserId, normalizedResolution, orderId]
    );

    if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REFUND) {
      await restoreStockForOrder(client, orderId);
    }

    if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REDELIVER) {
      await client.query(
        `UPDATE order_assignments SET status = 'CANCELLED', updated_at = NOW() WHERE order_id = $1`,
        [orderId]
      );
    }

    await resolveAdminTask(client, {
      orderId,
      taskType: ADMIN_TASK_TYPES.FAILED_DELIVERY,
      adminUserId,
    });

    const { rows: updatedRows } = await client.query(
      `SELECT id, customer_id, status, failed_delivery_resolution, payment_status
       FROM orders WHERE id = $1`,
      [orderId]
    );

    return { order: updatedRows[0], customerId: order.customer_id, resolution: normalizedResolution, refundAmount: Number(order.total_amount), paymentMode: order.payment_mode };
  });

  if (
    normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REFUND ||
    normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.DISCARD
  ) {
    const { processFailedDeliveryRefund } = require('./cashfreeRefund.service');
    processFailedDeliveryRefund({
      orderId,
      amount: result.refundAmount,
      paymentMode: result.paymentMode,
    }).catch((err) => {
      logger.error('failed_delivery_refund_gateway_failed', {
        orderId,
        resolution: normalizedResolution,
        error: err.message,
      });
    });
  }

  const customerMessages = {
    REDELIVER: {
      title: 'Redelivery scheduled',
      body: 'Your order is back at our store and will be redelivered soon.',
    },
    REFUND: {
      title: 'Refund initiated',
      body: 'We could not deliver your order. A refund has been initiated.',
    },
    DISCARD: {
      title: 'Order cancelled',
      body:
        String(result.paymentMode || '').toUpperCase() === 'ONLINE'
          ? 'We could not deliver your order. A refund has been initiated.'
          : 'We could not deliver your order and it has been cancelled.',
    },
  };
  const msg = customerMessages[normalizedResolution];

  await sendNotification({
    userId: result.customerId,
    role: ROLES.CUSTOMER,
    type: 'failed_delivery_resolved',
    title: msg.title,
    body: msg.body,
    data: { orderId, resolution: normalizedResolution },
    priority: 'high',
    channels: ['socket', 'push'],
    io,
  });

  if (io) {
    io.to(`customer_${result.customerId}`).emit('order:status_updated', {
      orderId,
      status: result.order.status,
      updatedAt: new Date().toISOString(),
    });
    io.to('admin_room').emit('order:failed_delivery_resolved', {
      orderId,
      resolution: normalizedResolution,
      status: result.order.status,
      timestamp: new Date().toISOString(),
    });
  }

  logger.info('failed_delivery_resolved', {
    orderId,
    adminUserId,
    resolution: normalizedResolution,
  });

  if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REDELIVER) {
    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.REDELIVERED,
      orderId,
      actorType: ACTOR_TYPES.ADMIN,
      actorId: adminUserId,
      previousState: 'FAILED_DELIVERY',
      newState: 'PACKED',
      metadata: { resolution: normalizedResolution },
    });
  } else if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REFUND) {
    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.REFUNDED,
      orderId,
      actorType: ACTOR_TYPES.ADMIN,
      actorId: adminUserId,
      previousState: 'FAILED_DELIVERY',
      newState: 'REFUNDED',
      metadata: { resolution: normalizedResolution },
    });
  }

  if (normalizedResolution === FAILED_DELIVERY_RESOLUTIONS.REDELIVER) {
    const { assignOrderToPartner } = require('./assignment.service');
    assignOrderToPartner({ orderId, io }).catch((err) => {
      logger.error('redeliver_auto_assign_failed', { orderId, error: err.message });
    });
  }

  return result;
}

module.exports = {
  listOpenAdminTasks,
  markFailedDelivery,
  confirmReturnToStore,
  resolveFailedDelivery,
  FAILED_DELIVERY_REASONS,
  RETURN_CONDITIONS,
  FAILED_DELIVERY_RESOLUTIONS,
};
