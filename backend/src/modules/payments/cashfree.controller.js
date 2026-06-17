const { query, getClient } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const cashfreeService = require('./cashfree.service');
const {
  verifyCashfreeWebhook,
  parseCashfreeWebhookEvent,
} = require('../../utils/cashfreeWebhook');
const { applyPaymentSuccess } = require('./payment-success');
const { emitOrderLifecycleEvent } = require('../../utils/orderSocketEmit');

const getReturnUrl = () =>
  process.env.CASHFREE_RETURN_URL || '';

const parseGatewayResponse = (value) => {
  if (!value) return {};
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch {
    return {};
  }
};

const extractGatewayPaymentId = (payload) => {
  const payment = payload?.data?.payment || {};
  return payment.cf_payment_id || payment.payment_id || null;
};

const mapCashfreeOrderStatus = (orderStatus) => {
  const normalized = String(orderStatus || '').toUpperCase();
  if (normalized === 'PAID') return 'SUCCESS';
  if (normalized === 'ACTIVE') return 'PENDING';
  if (normalized === 'EXPIRED') return 'FAILED';
  return normalized || 'PENDING';
};

const applyPaymentFailure = async (client, { paymentId, orderId, customerId, io }) => {
  await client.query(
    `UPDATE payment_transactions
     SET status = 'FAILED', updated_at = NOW()
     WHERE id = $1`,
    [paymentId]
  );
  await client.query(
    `UPDATE orders
     SET status = 'CANCELLED', payment_status = 'FAILED', updated_at = NOW()
     WHERE id = $1`,
    [orderId]
  );

  emitOrderLifecycleEvent(io, {
    orderId,
    customerId,
    payload: {
      orderId,
      status: 'CANCELLED',
      message: 'Payment was not completed',
      reason: 'payment_failed',
      updatedAt: new Date().toISOString(),
    },
  });
};

/**
 * @route POST /api/payments/cashfree/initiate
 */
const initiatePayment = async (req, res) => {
  const orderId = Number(req.body?.orderId);

  if (!Number.isInteger(orderId) || orderId <= 0) {
    return fail(res, 400, 'Order ID is required');
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    const orderResult = await client.query(
      `SELECT o.id, o.customer_id, o.total_amount, o.status, o.payment_mode, u.phone, u.email, u.name
       FROM orders o
       JOIN users u ON o.customer_id = u.id
       WHERE o.id = $1 AND o.customer_id = $2`,
      [orderId, req.user.id]
    );

    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return fail(res, 404, 'Order not found or access denied');
    }

    const order = orderResult.rows[0];

    if (order.status !== 'PLACED') {
      await client.query('ROLLBACK');
      return fail(res, 400, `Order cannot be paid for. Current status: ${order.status}`);
    }

    if (order.payment_mode !== 'ONLINE') {
      await client.query('ROLLBACK');
      return fail(res, 400, 'Order is not configured for online payment');
    }

    const existingResult = await client.query(
      `SELECT id, gateway_order_id, gateway_response
       FROM payment_transactions
       WHERE order_id = $1 AND gateway = 'CASHFREE' AND status = 'PENDING'
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [orderId]
    );

    if (existingResult.rows.length > 0) {
      const existing = existingResult.rows[0];
      const gatewayResponse = parseGatewayResponse(existing.gateway_response);
      await client.query('COMMIT');
      return ok(
        res,
        {
          payment_session_id: gatewayResponse.payment_session_id || null,
          cf_order_id: existing.gateway_order_id,
          orderId,
        },
        'Existing payment session reused'
      );
    }

    const returnUrl = getReturnUrl();
    if (!returnUrl) {
      await client.query('ROLLBACK');
      return fail(res, 500, 'Payment return URL is not configured');
    }

    const session = await cashfreeService.createOrder({
      orderId: String(orderId),
      amount: Number(order.total_amount),
      currency: 'INR',
      customerPhone: order.phone,
      customerEmail: order.email || undefined,
      customerName: order.name || undefined,
      returnUrl,
    });

    await client.query(
      `INSERT INTO payment_transactions (
         order_id, amount, status, gateway, gateway_order_id, gateway_response, created_at
       )
       VALUES ($1, $2, 'PENDING', 'CASHFREE', $3, $4, NOW())`,
      [
        orderId,
        order.total_amount,
        session.cf_order_id,
        JSON.stringify({
          payment_session_id: session.payment_session_id,
          cf_order_id: session.cf_order_id,
        }),
      ]
    );

    await client.query('COMMIT');

    return ok(
      res,
      {
        payment_session_id: session.payment_session_id,
        cf_order_id: session.cf_order_id,
        orderId,
      },
      'Payment initiated successfully'
    );
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore rollback errors */
    }
    logger.error('cashfree_initiate_failed', { orderId, error: error.message });
    return fail(res, 500, 'Payment initiation failed');
  } finally {
    client.release();
  }
};

/**
 * @route POST /api/payments/cashfree/webhook
 */
const handleWebhook = async (req, res) => {
  try {
    const { valid, payload } = verifyCashfreeWebhook(req);

    if (!valid || !payload) {
      return fail(res, 400, 'Invalid webhook signature');
    }

    let event;
    try {
      event = parseCashfreeWebhookEvent(payload);
    } catch (parseError) {
      logger.warn('cashfree_webhook_unsupported', { error: parseError.message });
      return ok(res, {}, 'Webhook received');
    }

    if (!event.orderId) {
      logger.warn('cashfree_webhook_missing_order_id', { eventType: event.eventType });
      return ok(res, {}, 'Webhook received');
    }

    const client = await getClient();

    try {
      await client.query('BEGIN');

      const paymentResult = await client.query(
        `SELECT pt.id, pt.order_id, pt.status, pt.amount,
                o.customer_id, o.status AS order_status
         FROM payment_transactions pt
         JOIN orders o ON o.id = pt.order_id
         WHERE pt.order_id = $1 AND pt.gateway = 'CASHFREE'
         ORDER BY pt.created_at DESC
         LIMIT 1
         FOR UPDATE`,
        [event.orderId]
      );

      if (paymentResult.rows.length === 0) {
        await client.query('ROLLBACK');
        logger.warn('cashfree_webhook_unknown_order', { orderId: event.orderId });
        return ok(res, {}, 'Webhook received');
      }

      const payment = paymentResult.rows[0];
      const io = req.app.get('io');

      if (payment.status !== 'PENDING' && payment.status !== 'INITIATED') {
        await client.query('ROLLBACK');
        return ok(res, {}, 'Webhook received');
      }

      if (event.eventType === 'PAYMENT_SUCCESS_WEBHOOK') {
        const gatewayPaymentId = extractGatewayPaymentId(payload);
        await applyPaymentSuccess(client, {
          paymentId: payment.id,
          orderId: payment.order_id,
          gatewayPaymentId,
          customerId: payment.customer_id,
          io,
        });
      } else if (
        event.eventType === 'PAYMENT_FAILED_WEBHOOK' ||
        event.eventType === 'PAYMENT_USER_DROPPED_WEBHOOK'
      ) {
        await applyPaymentFailure(client, {
          paymentId: payment.id,
          orderId: payment.order_id,
          customerId: payment.customer_id,
          io,
        });
      }

      await client.query('COMMIT');
      return ok(res, {}, 'Webhook received');
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {
        /* ignore rollback errors */
      }
      logger.error('cashfree_webhook_processing_failed', {
        orderId: event.orderId,
        error: error.message,
      });
      return ok(res, {}, 'Webhook received');
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('cashfree_webhook_failed', { error: error.message });
    return ok(res, {}, 'Webhook received');
  }
};

/**
 * @route GET /api/payments/cashfree/:orderId/status
 */
const getPaymentStatus = async (req, res) => {
  const orderId = Number(req.params.orderId);

  if (!Number.isInteger(orderId) || orderId <= 0) {
    return fail(res, 400, 'Order ID is required');
  }

  try {
    const paymentResult = await query(
      `SELECT pt.id, pt.status, pt.gateway_order_id, pt.gateway_response, o.customer_id
       FROM payment_transactions pt
       JOIN orders o ON o.id = pt.order_id
       WHERE pt.order_id = $1 AND pt.gateway = 'CASHFREE' AND o.customer_id = $2
       ORDER BY pt.created_at DESC
       LIMIT 1`,
      [orderId, req.user.id]
    );

    if (paymentResult.rows.length === 0) {
      return fail(res, 404, 'Payment not found');
    }

    const payment = paymentResult.rows[0];
    const gatewayResponse = parseGatewayResponse(payment.gateway_response);
    let status = payment.status;
    let paymentSessionId = gatewayResponse.payment_session_id || null;

    if (status === 'PENDING') {
      const liveStatus = await cashfreeService.getOrderStatus(String(orderId));
      status = mapCashfreeOrderStatus(liveStatus.order_status);
      paymentSessionId = liveStatus.payment_session_id || paymentSessionId;

      if (status !== payment.status) {
        await query(
          `UPDATE payment_transactions
           SET status = $1, updated_at = NOW()
           WHERE id = $2`,
          [status, payment.id]
        );
      }
    }

    return ok(
      res,
      {
        status,
        gateway_order_id: payment.gateway_order_id,
        payment_session_id: paymentSessionId,
      },
      'Payment status retrieved'
    );
  } catch (error) {
    logger.error('cashfree_status_check_failed', { orderId, error: error.message });
    return fail(res, 500, 'Status check failed');
  }
};

/**
 * @route POST /api/payments/cashfree/verify
 */
const verifyPayment = async (req, res) => {
  const orderId = Number(req.body?.orderId);

  if (!Number.isInteger(orderId) || orderId <= 0) {
    return fail(res, 400, 'orderId is required');
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    const paymentResult = await client.query(
      `SELECT pt.id, pt.order_id, pt.status, pt.gateway_order_id, pt.gateway_response,
              o.customer_id
       FROM payment_transactions pt
       JOIN orders o ON o.id = pt.order_id
       WHERE pt.order_id = $1 AND pt.gateway = 'CASHFREE' AND o.customer_id = $2
       ORDER BY pt.created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [orderId, req.user.id]
    );

    if (paymentResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return fail(res, 404, 'Payment not found');
    }

    const payment = paymentResult.rows[0];

    if (payment.status === 'SUCCESS') {
      await client.query('COMMIT');
      return ok(res, { verified: true, status: 'SUCCESS' }, 'Payment verified');
    }

    if (payment.status === 'FAILED') {
      await client.query('ROLLBACK');
      return ok(res, { verified: false, status: 'FAILED' }, 'Payment failed');
    }

    const payments = await cashfreeService.getPayments(String(orderId));
    const successfulPayment = payments.find(
      (entry) => String(entry.payment_status || '').toUpperCase() === 'SUCCESS'
    );

    if (!successfulPayment) {
      await client.query('ROLLBACK');
      return ok(res, { verified: false, status: 'PENDING' }, 'Payment pending');
    }

    const gatewayPaymentId =
      successfulPayment.cf_payment_id || successfulPayment.payment_id || null;
    const io = req.app.get('io');

    await applyPaymentSuccess(client, {
      paymentId: payment.id,
      orderId: payment.order_id,
      gatewayPaymentId,
      customerId: payment.customer_id,
      io,
    });

    await client.query('COMMIT');

    return ok(res, { verified: true, status: 'SUCCESS' }, 'Payment verified');
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore rollback errors */
    }
    logger.error('cashfree_verify_failed', { orderId, error: error.message });
    return fail(res, 500, 'Payment verification failed');
  } finally {
    client.release();
  }
};

module.exports = {
  initiatePayment,
  handleWebhook,
  getPaymentStatus,
  verifyPayment,
};
