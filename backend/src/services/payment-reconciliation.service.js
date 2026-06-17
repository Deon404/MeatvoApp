/**
 * PhonePe payment reconciliation — polls stale PENDING payments and cancels on failure.
 */

const { query, getClient } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { checkPaymentStatus } = require('../modules/payments/phonepe.service');
const { applyPaymentSuccess } = require('../modules/payments/payment-success');

const DEFAULT_TIMEOUT_MINUTES = Number(process.env.PAYMENT_RECONCILE_TIMEOUT_MINUTES || 15);
const RECONCILE_INTERVAL_MS = Number(process.env.PAYMENT_RECONCILE_INTERVAL_MS || 5 * 60 * 1000);

let reconcileTimer = null;

async function cancelOrderForPaymentFailure(orderId, customerId, io, reason = 'payment_failed') {
  await query(
    `UPDATE orders
     SET status = 'CANCELLED', payment_status = 'FAILED', updated_at = NOW()
     WHERE id = $1 AND status IN ('PLACED', 'PAYMENT_PENDING')`,
    [orderId]
  );

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
  io.to('staff:orders').emit('order:updated', payload);
  io.to('staff_room').emit('order:updated', payload);
}

async function reconcileStalePayments(io = null) {
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

  if (!rows.length) return { checked: 0, updated: 0 };

  let updated = 0;

  for (const payment of rows) {
    if (!payment.gateway_transaction_id) continue;

    try {
      const statusResponse = await checkPaymentStatus(payment.gateway_transaction_id);
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

  return { checked: rows.length, updated };
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
