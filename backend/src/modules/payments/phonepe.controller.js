const asyncHandler = require('express-async-handler');
const { getClient } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const phonepeService = require('./phonepe.service');
const { reserveStockForPaidOrder } = require('./payment-stock');

/**
 * Client-side payment verification after PhonePe redirect.
 * Polls PhonePe status API (checksum-signed) and updates order state.
 *
 * @route POST /api/payments/verify
 */
const verifyPayment = asyncHandler(async (req, res) => {
  const merchantTransactionId = String(
    req.validated.body.transactionId || req.validated.body.merchantTransactionId || ''
  ).trim();

  if (!merchantTransactionId) {
    return fail(res, 400, 'transactionId is required');
  }

  if (!phonepeService.isConfigured()) {
    return fail(res, 503, 'Payment gateway is not configured');
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    const paymentResult = await client.query(
      `SELECT pt.id, pt.order_id, pt.amount, pt.status, pt.gateway_transaction_id,
              o.customer_id, o.status AS order_status
       FROM payment_transactions pt
       JOIN orders o ON o.id = pt.order_id
       WHERE pt.gateway_transaction_id = $1 AND o.customer_id = $2
       FOR UPDATE`,
      [merchantTransactionId, req.user.id]
    );

    if (paymentResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return fail(res, 404, 'Payment transaction not found');
    }

    const payment = paymentResult.rows[0];

    if (payment.status === 'SUCCESS') {
      await client.query('COMMIT');
      return ok(
        res,
        { success: true, status: 'paid', orderId: payment.order_id },
        'Payment verified'
      );
    }

    if (payment.status === 'FAILED') {
      await client.query('ROLLBACK');
      return ok(
        res,
        { success: false, status: 'failed', orderId: payment.order_id },
        'Payment failed'
      );
    }

    const statusResponse = await phonepeService.checkPaymentStatus(merchantTransactionId);

    if (!statusResponse.success) {
      await client.query('ROLLBACK');
      return fail(res, 502, statusResponse.error || 'Unable to verify payment with gateway');
    }

    const phonePeData = statusResponse.data;
    const state = phonePeData?.state;

    if (state === 'COMPLETED') {
      const expectedPaise = Math.round(Number(payment.amount) * 100);
      const receivedPaise = Number(phonePeData.amount);
      if (Number.isFinite(receivedPaise) && receivedPaise !== expectedPaise) {
        await client.query('ROLLBACK');
        return fail(res, 400, 'Amount mismatch');
      }

      await client.query(
        `UPDATE payment_transactions
         SET status = 'SUCCESS', gateway_response = $1, updated_at = NOW()
         WHERE id = $2`,
        [JSON.stringify(phonePeData), payment.id]
      );
      await reserveStockForPaidOrder(client, payment.order_id);
      await client.query(
        `UPDATE orders
         SET status = 'CONFIRMED', payment_status = 'PAID', updated_at = NOW()
         WHERE id = $1`,
        [payment.order_id]
      );
      await client.query('COMMIT');

      const io = req.app.get('io');
      if (io) {
        const payload = {
          orderId: payment.order_id,
          customerId: payment.customer_id,
          totalAmount: Number(payment.amount || 0),
          createdAt: new Date().toISOString(),
        };
        io.to('admin_room').emit('order:new', payload);
      }

      logger.info('payment_verified', {
        orderId: payment.order_id,
        merchantTransactionId,
      });

      return ok(
        res,
        { success: true, status: 'paid', orderId: payment.order_id },
        'Payment verified'
      );
    }

    if (state === 'FAILED') {
      await client.query(
        `UPDATE payment_transactions
         SET status = 'FAILED', gateway_response = $1, updated_at = NOW()
         WHERE id = $2`,
        [JSON.stringify(phonePeData), payment.id]
      );
      await client.query(
        `UPDATE orders SET status = 'CANCELLED', payment_status = 'FAILED', updated_at = NOW()
         WHERE id = $1 AND status IN ('PLACED', 'PAYMENT_PENDING')`,
        [payment.order_id]
      );
      await client.query('COMMIT');
      return ok(
        res,
        { success: false, status: 'failed', orderId: payment.order_id },
        'Payment failed'
      );
    }

    await client.query('ROLLBACK');
    return ok(
      res,
      { success: false, status: 'pending', orderId: payment.order_id },
      'Payment pending'
    );
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore rollback errors */
    }
    logger.error('verify_payment_failed', {
      error: err.message,
      merchantTransactionId,
    });
    return fail(res, err.statusCode || 500, 'Payment verification failed');
  } finally {
    client.release();
  }
});

module.exports = { verifyPayment };
