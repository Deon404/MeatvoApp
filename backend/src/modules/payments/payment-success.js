const { reserveStockForPaidOrder } = require('./payment-stock');
const { emitOrderLifecycleEvent } = require('../../utils/orderSocketEmit');
const { logger } = require('../../utils/logger');

/**
 * Shared ONLINE payment success handler (webhook, verify, reconciliation).
 * Idempotent: skips stock deduction when payment is already SUCCESS.
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
    `SELECT status FROM payment_transactions WHERE id = $1 FOR UPDATE`,
    [paymentId]
  );

  if (!lockResult.rows.length) {
    return { applied: false, reason: 'not_found' };
  }

  const currentStatus = lockResult.rows[0].status;
  if (currentStatus === 'SUCCESS') {
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
    io.to('staff_room').emit('order:new', {
      orderId: order.id,
      customerPhone: order.customer_phone,
      totalAmount: Number(order.total_amount),
      createdAt: new Date().toISOString(),
    });
  }

  return { applied: true };
};

module.exports = { applyPaymentSuccess };
