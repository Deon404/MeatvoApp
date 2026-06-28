const { query } = require('../db/postgres');
const cashfreeService = require('../modules/payments/cashfree.service');
const { logger } = require('../utils/logger');
const {
  PARTIAL_REFUND_STATUS,
  FAILED_DELIVERY_REFUND_REASON,
} = require('../constants/weightReconciliation.constants');

const ONLINE_PAYMENT_MODES = new Set(['ONLINE']);

const isOnlinePayment = (paymentMode) =>
  ONLINE_PAYMENT_MODES.has(String(paymentMode || '').trim().toUpperCase());

const buildIdempotencyKey = ({ orderId, partialRefundId, reason }) => {
  const prefix = reason === FAILED_DELIVERY_REFUND_REASON ? 'fd' : 'wr';
  const raw = `${prefix}${orderId}r${partialRefundId}`;
  return raw.replace(/[^a-zA-Z0-9]/g, '').slice(0, 40);
};

const findSuccessfulCashfreePayment = async (orderId, client = null) => {
  const db = client || { query };
  const { rows } = await db.query(
    `SELECT id, order_id, amount, gateway_payment_id, status
     FROM payment_transactions
     WHERE order_id = $1
       AND gateway = 'CASHFREE'
       AND status = 'SUCCESS'
     ORDER BY created_at DESC
     LIMIT 1`,
    [orderId]
  );
  return rows[0] || null;
};

const markRefundSubmitted = async ({
  partialRefundId,
  gatewayRefundId,
  gatewayStatus,
  client = null,
}) => {
  const db = client || { query };
  const nextStatus =
    String(gatewayStatus || '').toUpperCase() === 'SUCCESS'
      ? PARTIAL_REFUND_STATUS.SUCCESS
      : PARTIAL_REFUND_STATUS.SUBMITTED;

  await db.query(
    `UPDATE order_partial_refunds
     SET status = $1,
         gateway_refund_id = COALESCE($2, gateway_refund_id),
         metadata = metadata || $3::jsonb
     WHERE id = $4`,
    [
      nextStatus,
      gatewayRefundId,
      JSON.stringify({
        gatewayRefundStatus: gatewayStatus || null,
        submittedAt: new Date().toISOString(),
      }),
      partialRefundId,
    ]
  );
};

const markRefundFailed = async ({ partialRefundId, errorMessage, client = null }) => {
  const db = client || { query };
  await db.query(
    `UPDATE order_partial_refunds
     SET status = $1,
         metadata = metadata || $2::jsonb
     WHERE id = $3
       AND gateway_refund_id IS NULL`,
    [
      PARTIAL_REFUND_STATUS.FAILED,
      JSON.stringify({
        lastError: String(errorMessage || 'unknown').slice(0, 500),
        failedAt: new Date().toISOString(),
      }),
      partialRefundId,
    ]
  );
};

/**
 * Submit a single partial/full refund row to Cashfree (idempotent, retry-safe).
 * @returns {Promise<{ submitted: boolean, skipped?: boolean, reason?: string, cfRefundId?: string|null }>}
 */
const submitPartialRefundToGateway = async ({ partialRefundId, client = null }) => {
  const db = client || { query };

  const { rows } = await db.query(
    `SELECT id, order_id, order_item_id, amount, reason, status, payment_mode,
            gateway_refund_id, idempotency_key
     FROM order_partial_refunds
     WHERE id = $1
     FOR UPDATE`,
    [partialRefundId]
  );
  const refundRow = rows[0];
  if (!refundRow) {
    return { submitted: false, reason: 'refund_not_found' };
  }

  if (refundRow.gateway_refund_id) {
    return { submitted: true, skipped: true, reason: 'already_submitted' };
  }

  if (!isOnlinePayment(refundRow.payment_mode)) {
    return { submitted: false, skipped: true, reason: 'not_online_payment' };
  }

  const terminalStatuses = new Set([
    PARTIAL_REFUND_STATUS.SUCCESS,
    PARTIAL_REFUND_STATUS.SUBMITTED,
  ]);
  if (terminalStatuses.has(String(refundRow.status || '').toUpperCase())) {
    return { submitted: true, skipped: true, reason: 'already_processed' };
  }

  const payment = await findSuccessfulCashfreePayment(refundRow.order_id, db);
  if (!payment) {
    await markRefundFailed({
      partialRefundId,
      errorMessage: 'No successful Cashfree payment found for order',
      client: db,
    });
    return { submitted: false, reason: 'payment_not_found' };
  }

  const idempotencyKey =
    refundRow.idempotency_key ||
    buildIdempotencyKey({
      orderId: refundRow.order_id,
      partialRefundId: refundRow.id,
      reason: refundRow.reason,
    });

  if (!refundRow.idempotency_key) {
    await db.query(
      `UPDATE order_partial_refunds SET idempotency_key = $1 WHERE id = $2`,
      [idempotencyKey, partialRefundId]
    );
  }

  const refundAmount = Number(refundRow.amount);
  const paidAmount = Number(payment.amount);
  if (!Number.isFinite(refundAmount) || refundAmount <= 0) {
    return { submitted: false, reason: 'invalid_refund_amount' };
  }
  if (Number.isFinite(paidAmount) && refundAmount > paidAmount) {
    await markRefundFailed({
      partialRefundId,
      errorMessage: `Refund amount ${refundAmount} exceeds paid amount ${paidAmount}`,
      client: db,
    });
    return { submitted: false, reason: 'amount_exceeds_payment' };
  }

  try {
    const gatewayResult = await cashfreeService.createRefund({
      orderId: String(refundRow.order_id),
      refundAmount,
      refundId: idempotencyKey,
      refundNote: String(refundRow.reason || 'refund').slice(0, 100),
    });

    await markRefundSubmitted({
      partialRefundId,
      gatewayRefundId: gatewayResult.cf_refund_id || gatewayResult.refund_id,
      gatewayStatus: gatewayResult.refund_status,
      client: db,
    });

    if (
      payment.id &&
      String(refundRow.reason || '') === FAILED_DELIVERY_REFUND_REASON
    ) {
      await db.query(
        `UPDATE payment_transactions
         SET status = 'REFUNDED', updated_at = NOW()
         WHERE id = $1
           AND status = 'SUCCESS'`,
        [payment.id]
      );
    }

    return {
      submitted: true,
      cfRefundId: gatewayResult.cf_refund_id || gatewayResult.refund_id,
    };
  } catch (err) {
    await markRefundFailed({
      partialRefundId,
      errorMessage: err.message,
      client: db,
    });
    logger.error('cashfree_refund_submit_failed', {
      partialRefundId,
      orderId: refundRow.order_id,
      error: err.message,
    });
    return { submitted: false, reason: 'gateway_error', error: err.message };
  }
};

/**
 * Process all pending gateway refunds for an order (weight reconciliation path).
 */
const processPendingRefundsForOrder = async (orderId) => {
  const { rows } = await query(
    `SELECT id
     FROM order_partial_refunds
     WHERE order_id = $1
       AND payment_mode = 'ONLINE'
       AND gateway_refund_id IS NULL
       AND status IN ($2, $3)
     ORDER BY id ASC`,
    [orderId, PARTIAL_REFUND_STATUS.PENDING, PARTIAL_REFUND_STATUS.FAILED]
  );

  const results = [];
  for (const row of rows) {
    results.push(await submitPartialRefundToGateway({ partialRefundId: row.id }));
  }
  return results;
};

/**
 * Record and submit a full refund for failed-delivery resolution (ONLINE only).
 */
const processFailedDeliveryRefund = async ({ orderId, amount, paymentMode, client = null }) => {
  const db = client || { query };
  const normalizedMode = String(paymentMode || '').trim().toUpperCase();

  if (!isOnlinePayment(normalizedMode)) {
    return { submitted: false, skipped: true, reason: 'not_online_payment' };
  }

  const refundAmount = Number(amount);
  if (!Number.isFinite(refundAmount) || refundAmount <= 0) {
    return { submitted: false, reason: 'invalid_refund_amount' };
  }

  const { rows: existingRows } = await db.query(
    `SELECT id, gateway_refund_id, status
     FROM order_partial_refunds
     WHERE order_id = $1 AND reason = $2
     ORDER BY id DESC
     LIMIT 1`,
    [orderId, FAILED_DELIVERY_REFUND_REASON]
  );

  let partialRefundId;
  if (existingRows[0]) {
    partialRefundId = existingRows[0].id;
    if (existingRows[0].gateway_refund_id) {
      return { submitted: true, skipped: true, reason: 'already_submitted' };
    }
  } else {
    const idempotencyKey = buildIdempotencyKey({
      orderId,
      partialRefundId: `fd${orderId}`,
      reason: FAILED_DELIVERY_REFUND_REASON,
    });
    const { rows: inserted } = await db.query(
      `INSERT INTO order_partial_refunds
         (order_id, order_item_id, amount, reason, status, payment_mode, idempotency_key, metadata)
       VALUES ($1, NULL, $2, $3, $4, $5, $6, $7::jsonb)
       RETURNING id`,
      [
        orderId,
        refundAmount,
        FAILED_DELIVERY_REFUND_REASON,
        PARTIAL_REFUND_STATUS.PENDING,
        normalizedMode,
        idempotencyKey,
        JSON.stringify({ source: 'failed_delivery' }),
      ]
    );
    if (inserted[0]) {
      partialRefundId = inserted[0].id;
    } else {
      const { rows: retryRows } = await db.query(
        `SELECT id, gateway_refund_id FROM order_partial_refunds
         WHERE order_id = $1 AND reason = $2
         ORDER BY id DESC LIMIT 1`,
        [orderId, FAILED_DELIVERY_REFUND_REASON]
      );
      partialRefundId = retryRows[0]?.id;
      if (retryRows[0]?.gateway_refund_id) {
        return { submitted: true, skipped: true, reason: 'already_submitted' };
      }
    }
  }

  if (!partialRefundId) {
    return { submitted: false, reason: 'refund_record_missing' };
  }

  return submitPartialRefundToGateway({ partialRefundId, client: db });
};

module.exports = {
  isOnlinePayment,
  buildIdempotencyKey,
  findSuccessfulCashfreePayment,
  submitPartialRefundToGateway,
  processPendingRefundsForOrder,
  processFailedDeliveryRefund,
};
