const { reserveStockForPaidOrder } = require('./payment-stock');
const { emitOrderLifecycleEvent } = require('../../utils/orderSocketEmit');
const { instrumentOrderConfirmed } = require('../../utils/operationalEvents.util');
const { logger } = require('../../utils/logger');

const UNCONFIRMED_ORDER_STATUSES = new Set(['PLACED', 'PAYMENT_PENDING']);

const confirmOrderAfterPayment = async (client, { orderId, customerId, io }) => {
  await reserveStockForPaidOrder(client, orderId);
  const orderUpdateResult = await client.query(
    `UPDATE orders o
     SET status = 'CONFIRMED', payment_status = 'PAID', updated_at = NOW()
     FROM users u
     WHERE o.id = $1 AND o.customer_id = u.id
       AND o.status IN ('PLACED', 'PAYMENT_PENDING')
     RETURNING o.id, o.total_amount, u.phone AS customer_phone`,
    [orderId]
  );

  emitOrderLifecycleEvent(io, {
    orderId,
    customerId,
    payload: {
      orderId,
      status: 'CONFIRMED',
      message: 'Your order is confirmed — preparing now',
      updatedAt: new Date().toISOString(),
    },
  });

  if (io && orderUpdateResult.rows.length) {
    const order = orderUpdateResult.rows[0];
    instrumentOrderConfirmed(io, {
      orderId: order.id,
      actorRole: 'system',
      metadata: { source: 'payment_success' },
    });
  }

  return orderUpdateResult.rows.length > 0;
};

/**
 * Shared ONLINE payment success handler (webhook, verify, status poll, reconciliation).
 * Idempotent: skips when payment and order are both fully confirmed.
 * Recovers when payment row is SUCCESS but order was never confirmed (legacy status poll bug).
 */
const applyPaymentSuccess = async (client, {
  paymentId,
  orderId,
  customerId,
  io,
  gatewayPaymentId = null,
  gatewayResponse = null,
}) => {
  const lockResult = await client.query(
    `SELECT pt.status AS payment_status, o.status AS order_status
     FROM payment_transactions pt
     JOIN orders o ON o.id = pt.order_id
     WHERE pt.id = $1
     FOR UPDATE OF pt`,
    [paymentId]
  );

  if (!lockResult.rows.length) {
    return { applied: false, reason: 'not_found' };
  }

  const currentStatus = lockResult.rows[0].payment_status;
  const orderStatus = lockResult.rows[0].order_status;

  if (currentStatus === 'SUCCESS') {
    if (UNCONFIRMED_ORDER_STATUSES.has(orderStatus)) {
      const confirmed = await confirmOrderAfterPayment(client, {
        orderId,
        customerId,
        io,
      });
      if (confirmed) {
        logger.warn('payment_success_order_recovered', { paymentId, orderId });
        return { applied: true, reason: 'order_recovered' };
      }
      return { applied: false, reason: 'order_not_confirmable' };
    }
    return { applied: false, reason: 'already_success' };
  }

  if (currentStatus !== 'PENDING' && currentStatus !== 'INITIATED') {
    return { applied: false, reason: 'invalid_status' };
  }

  let updateResult;
  if (gatewayPaymentId != null) {
    updateResult = await client.query(
      `UPDATE payment_transactions
       SET status = 'SUCCESS', gateway_payment_id = $1, updated_at = NOW()
       WHERE id = $2 AND status IN ('INITIATED', 'PENDING')
       RETURNING id`,
      [gatewayPaymentId, paymentId]
    );
  } else if (gatewayResponse != null) {
    const serialized =
      typeof gatewayResponse === 'string'
        ? gatewayResponse
        : JSON.stringify(gatewayResponse);
    updateResult = await client.query(
      `UPDATE payment_transactions
       SET status = 'SUCCESS', gateway_response = $1, updated_at = NOW()
       WHERE id = $2 AND status IN ('INITIATED', 'PENDING')
       RETURNING id`,
      [serialized, paymentId]
    );
  } else {
    updateResult = await client.query(
      `UPDATE payment_transactions
       SET status = 'SUCCESS', updated_at = NOW()
       WHERE id = $1 AND status IN ('INITIATED', 'PENDING')
       RETURNING id`,
      [paymentId]
    );
  }

  if (!updateResult.rows.length) {
    return { applied: false, reason: 'already_processed' };
  }

  await confirmOrderAfterPayment(client, { orderId, customerId, io });

  return { applied: true };
};

module.exports = { applyPaymentSuccess };
