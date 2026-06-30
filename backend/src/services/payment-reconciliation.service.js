/**
 * Payment reconciliation — polls stale PENDING payments (PhonePe + Cashfree)
 * and applies success or cancels on failure.
 */

const { query, getClient } = require('../db/postgres');
const { logger } = require('../utils/logger');
const phonepeService = require('../modules/payments/phonepe.service');
const cashfreeService = require('../modules/payments/cashfree.service');
const { applyPaymentSuccess } = require('../modules/payments/payment-success');
const { resolveSuccessfulCashfreePayment } = require('../modules/payments/cashfree.controller');
const { releaseCouponForOrder } = require('../utils/couponRelease.util');

const DEFAULT_TIMEOUT_MINUTES = Number(process.env.PAYMENT_RECONCILE_TIMEOUT_MINUTES || 15);
const RECONCILE_INTERVAL_MS = Number(process.env.PAYMENT_RECONCILE_INTERVAL_MS || 5 * 60 * 1000);

const CASHFREE_SUCCESS_STATUSES = new Set(['SUCCESS', 'PAID']);
const CASHFREE_FAILURE_STATUSES = new Set(['FAILED', 'CANCELLED', 'EXPIRED']);
const CASHFREE_PENDING_STATUSES = new Set(['ACTIVE', 'PENDING']);

let reconcileTimer = null;

async function cancelOrderForPaymentFailure(orderId, customerId, io, reason = 'payment_failed') {
  await query(
    `UPDATE orders
     SET status = 'CANCELLED', payment_status = 'FAILED', updated_at = NOW()
     WHERE id = $1 AND status IN ('PLACED', 'PAYMENT_PENDING')`,
    [orderId]
  );

  await releaseCouponForOrder(null, orderId);

  if (!io) return;

  const payload = {
    orderId,
    status: 'CANCELLED',
    reason,
    updatedAt: new Date().toISOString(),
  };

  // LIFECYCLE FIX: emit to canonical + legacy socket rooms
  io.to(`order:${orderId}`).emit('order:status_updated', payload);
  if (customerId) {
    io.to(`customer_${customerId}`).emit('order:status_updated', payload);
  }
  io.to('admin:orders').emit('order:updated', payload);
  io.to('admin_room').emit('order:updated', payload);
}

async function reconcileStalePayments(io = null) {
  let checked = 0;
  let updated = 0;

  const { rows } = await query(
    `SELECT pt.id, pt.order_id, pt.gateway_transaction_id, pt.status,
            o.customer_id, o.payment_mode, o.status AS order_status
     FROM payment_transactions pt
     JOIN orders o ON o.id = pt.order_id
     WHERE pt.status IN ('INITIATED', 'PENDING')
       AND o.payment_mode = 'ONLINE'
       AND o.status IN ('PLACED', 'PAYMENT_PENDING')
       AND pt.created_at < NOW() - ($1::text || ' minutes')::interval
     ORDER BY pt.created_at ASC
     LIMIT 50`,
    [String(DEFAULT_TIMEOUT_MINUTES)]
  );

  checked += rows.length;

  for (const payment of rows) {
    if (!payment.gateway_transaction_id) continue;

    try {
      const statusResponse = await phonepeService.checkPaymentStatus(payment.gateway_transaction_id);
      if (!statusResponse.success) continue;

      const state = statusResponse.data?.state;

      if (state === 'COMPLETED') {
        const client = await getClient();
        try {
          await client.query('BEGIN');
          const result = await applyPaymentSuccess(client, {
            paymentId: payment.id,
            orderId: payment.order_id,
            customerId: payment.customer_id,
            io,
            gatewayResponse: statusResponse.data,
          });
          if (result.applied) {
            await client.query('COMMIT');
            updated += 1;
            logger.info('payment_reconcile_success', { orderId: payment.order_id });
          } else {
            await client.query('ROLLBACK');
            logger.info('payment_reconcile_success_skipped', {
              orderId: payment.order_id,
              reason: result.reason,
            });
          }
        } catch (err) {
          try {
            await client.query('ROLLBACK');
          } catch (_) {
            /* ignore rollback errors */
          }
          throw err;
        } finally {
          client.release();
        }
      } else if (state === 'FAILED') {
        await query(
          `UPDATE payment_transactions
           SET status = 'FAILED', gateway_response = $1, updated_at = NOW()
           WHERE id = $2`,
          [JSON.stringify(statusResponse.data), payment.id]
        );
        await cancelOrderForPaymentFailure(payment.order_id, payment.customer_id, io);
        updated += 1;
        logger.info('payment_reconcile_failed_cancelled', { orderId: payment.order_id });
      }
    } catch (err) {
      logger.error('payment_reconcile_item_failed', {
        orderId: payment.order_id,
        error: err.message,
      });
    }
  }

  const { rows: cashfreeRows } = await query(
    `SELECT pt.id, pt.order_id, pt.amount, pt.gateway_order_id, pt.status,
            o.customer_id, o.payment_mode, o.status AS order_status
     FROM payment_transactions pt
     JOIN orders o ON o.id = pt.order_id
     WHERE pt.gateway = 'CASHFREE'
       AND pt.status IN ('INITIATED', 'PENDING')
       AND o.payment_mode = 'ONLINE'
       AND o.status IN ('PLACED', 'PAYMENT_PENDING')
       AND pt.created_at < NOW() - ($1::text || ' minutes')::interval
     ORDER BY pt.created_at ASC
     LIMIT 50`,
    [String(DEFAULT_TIMEOUT_MINUTES)]
  );

  checked += cashfreeRows.length;

  for (const payment of cashfreeRows) {
    if (!payment.gateway_order_id) {
      logger.info('payment_reconcile_cashfree_skipped', {
        orderId: payment.order_id,
        gateway_order_id: payment.gateway_order_id,
        reason: 'missing_gateway_order_id',
      });
      continue;
    }

    try {
      // Cashfree GET /orders/{id} expects the merchant order_id (Meatvo order ID),
      // consistent with cashfree.controller getPaymentStatus.
      const liveStatus = await cashfreeService.getOrderStatus(String(payment.order_id));
      const orderStatus = String(liveStatus.order_status || '').toUpperCase();

      if (CASHFREE_SUCCESS_STATUSES.has(orderStatus)) {
        const gatewayPaymentId = await resolveSuccessfulCashfreePayment(
          payment.order_id,
          payment.amount
        );

        if (!gatewayPaymentId) {
          logger.warn('reconciliation_amount_verify_failed', {
            orderId: payment.order_id,
          });
          continue;
        }

        const client = await getClient();
        try {
          await client.query('BEGIN');
          const result = await applyPaymentSuccess(client, {
            paymentId: payment.id,
            orderId: payment.order_id,
            customerId: payment.customer_id,
            io,
            gatewayPaymentId,
          });
          if (result.applied) {
            await client.query('COMMIT');
            updated += 1;
            logger.info('payment_reconcile_cashfree_success', {
              orderId: payment.order_id,
              gateway_order_id: payment.gateway_order_id,
            });
          } else {
            await client.query('ROLLBACK');
            logger.info('payment_reconcile_cashfree_success_skipped', {
              orderId: payment.order_id,
              gateway_order_id: payment.gateway_order_id,
              reason: result.reason,
            });
          }
        } catch (err) {
          try {
            await client.query('ROLLBACK');
          } catch (_) {
            /* ignore rollback errors */
          }
          throw err;
        } finally {
          client.release();
        }
      } else if (CASHFREE_FAILURE_STATUSES.has(orderStatus)) {
        await query(
          `UPDATE payment_transactions
           SET status = 'FAILED', gateway_response = $1, updated_at = NOW()
           WHERE id = $2`,
          [JSON.stringify(liveStatus), payment.id]
        );
        await cancelOrderForPaymentFailure(payment.order_id, payment.customer_id, io);
        updated += 1;
        logger.info('payment_reconcile_cashfree_cancelled', {
          orderId: payment.order_id,
          gateway_order_id: payment.gateway_order_id,
          orderStatus,
        });
      } else if (CASHFREE_PENDING_STATUSES.has(orderStatus)) {
        logger.info('payment_reconcile_cashfree_skipped', {
          orderId: payment.order_id,
          gateway_order_id: payment.gateway_order_id,
          orderStatus,
          reason: 'still_pending',
        });
      } else {
        logger.info('payment_reconcile_cashfree_skipped', {
          orderId: payment.order_id,
          gateway_order_id: payment.gateway_order_id,
          orderStatus,
          reason: 'unhandled_status',
        });
      }
    } catch (err) {
      logger.error('payment_reconcile_cashfree_item_failed', {
        orderId: payment.order_id,
        gateway_order_id: payment.gateway_order_id,
        error: err.message,
      });
    }
  }

  return { checked, updated };
}

function startPaymentReconciliation(io) {
  if (reconcileTimer) return;

  const run = () => {
    reconcileStalePayments(io).catch((err) => {
      logger.error('payment_reconcile_run_failed', { error: err.message });
    });
  };

  run();
  reconcileTimer = setInterval(run, RECONCILE_INTERVAL_MS);
  logger.info('payment_reconciliation_started', {
    intervalMs: RECONCILE_INTERVAL_MS,
    timeoutMinutes: DEFAULT_TIMEOUT_MINUTES,
  });
}

function stopPaymentReconciliation() {
  if (reconcileTimer) {
    clearInterval(reconcileTimer);
    reconcileTimer = null;
  }
}

module.exports = {
  reconcileStalePayments,
  cancelOrderForPaymentFailure,
  startPaymentReconciliation,
  stopPaymentReconciliation,
};
