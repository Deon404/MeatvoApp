const { getClient } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const cashfreeService = require('./cashfree.service');
const {
  verifyCashfreeWebhook,
  parseCashfreeWebhookEvent,
} = require('../../utils/cashfreeWebhook');
const { applyPaymentSuccess } = require('./payment-success');
const { emitOrderLifecycleEvent } = require('../../utils/orderSocketEmit');
const { releaseCouponForOrder } = require('../../utils/couponRelease.util');
const sentry = require('../../utils/sentry');

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

const isAmountMismatch = (storedAmount, receivedAmount) => {
  const expectedPaise = Math.round(Number(storedAmount) * 100);
  const receivedPaise = Math.round(Number(receivedAmount) * 100);
  return Number.isFinite(receivedPaise) && receivedPaise !== expectedPaise;
};

const reportAmountMismatch = ({ paymentId, orderId, expectedAmount, receivedAmount, source }) => {
  const details = {
    paymentId,
    orderId,
    expectedAmount: Number(expectedAmount),
    receivedAmount: Number(receivedAmount),
    source,
  };
  logger.error('cashfree_amount_mismatch', details);
  sentry.captureMessage(
    'Cashfree payment amount mismatch — manual review required',
    'error',
    { paymentMismatch: details }
  );
};

const mapCashfreeOrderStatus = (orderStatus) => {
  const normalized = String(orderStatus || '').toUpperCase();
  if (normalized === 'PAID') return 'SUCCESS';
  if (normalized === 'ACTIVE') return 'PENDING';
  if (normalized === 'EXPIRED') return 'FAILED';
  return normalized || 'PENDING';
};

const UNCONFIRMED_ORDER_STATUSES = new Set(['PLACED', 'PAYMENT_PENDING']);

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

  await releaseCouponForOrder(client, orderId);

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

/** User cancelled SDK checkout — keep order retryable, mark payment as failed. */
const applyPaymentAbandon = async (
  client,
  { paymentId, orderId, customerId, io, reason = 'user_abandoned' }
) => {
  if (paymentId) {
    await client.query(
      `UPDATE payment_transactions
       SET status = 'FAILED', updated_at = NOW()
       WHERE id = $1 AND status IN ('INITIATED', 'PENDING')`,
      [paymentId]
    );
  }

  await client.query(
    `UPDATE orders
     SET payment_status = 'FAILED', updated_at = NOW()
     WHERE id = $1
       AND status IN ('PLACED', 'PAYMENT_PENDING')
       AND payment_mode = 'ONLINE'`,
    [orderId]
  );

  emitOrderLifecycleEvent(io, {
    orderId,
    customerId,
    payload: {
      orderId,
      status: 'PLACED',
      paymentStatus: 'FAILED',
      message: 'Payment was not completed',
      reason,
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

    if (!UNCONFIRMED_ORDER_STATUSES.has(order.status)) {
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
    logger.error('cashfree_initiate_failed', {
      orderId,
      error: error.message,
      stack: error.stack,
      cashfreeEnv: process.env.CASHFREE_ENV,
    });
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
        if (isAmountMismatch(payment.amount, event.amount)) {
          reportAmountMismatch({
            paymentId: payment.id,
            orderId: payment.order_id,
            expectedAmount: payment.amount,
            receivedAmount: event.amount,
            source: 'webhook',
          });
          await client.query('ROLLBACK');
          return ok(res, {}, 'Webhook received');
        }

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

const resolveSuccessfulCashfreePayment = async (orderId, storedAmount) => {
  const payments = await cashfreeService.getPayments(String(orderId));
  const successfulPayment = payments.find(
    (entry) => String(entry.payment_status || '').toUpperCase() === 'SUCCESS'
  );

  if (!successfulPayment) {
    return null;
  }

  const receivedAmount =
    successfulPayment.payment_amount != null
      ? successfulPayment.payment_amount
      : successfulPayment.order_amount;

  if (isAmountMismatch(storedAmount, receivedAmount)) {
    reportAmountMismatch({
      paymentId: null,
      orderId,
      expectedAmount: storedAmount,
      receivedAmount,
      source: 'status_poll',
    });
    return null;
  }

  return successfulPayment.cf_payment_id || successfulPayment.payment_id || null;
};

/**
 * @route GET /api/payments/cashfree/:orderId/status
 */
const getPaymentStatus = async (req, res) => {
  const orderId = Number(req.params.orderId);

  if (!Number.isInteger(orderId) || orderId <= 0) {
    return fail(res, 400, 'Order ID is required');
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    const paymentResult = await client.query(
      `SELECT pt.id, pt.status, pt.amount, pt.gateway_order_id, pt.gateway_response,
              pt.gateway_payment_id, o.customer_id, o.status AS order_status
       FROM payment_transactions pt
       JOIN orders o ON o.id = pt.order_id
       WHERE pt.order_id = $1 AND pt.gateway = 'CASHFREE' AND o.customer_id = $2
       ORDER BY pt.created_at DESC
       LIMIT 1
       FOR UPDATE OF pt`,
      [orderId, req.user.id]
    );

    if (paymentResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return fail(res, 404, 'Payment not found');
    }

    const payment = paymentResult.rows[0];
    const gatewayResponse = parseGatewayResponse(payment.gateway_response);
    let status = payment.status;
    let orderStatus = payment.order_status;
    let gatewayPaymentId = payment.gateway_payment_id || null;
    let paymentSessionId = gatewayResponse.payment_session_id || null;
    const io = req.app.get('io');

    const confirmIfPaidAtGateway = async () => {
      const gatewayPaymentIdFromApi = await resolveSuccessfulCashfreePayment(
        orderId,
        payment.amount
      );
      if (!gatewayPaymentIdFromApi) {
        return false;
      }

      await applyPaymentSuccess(client, {
        paymentId: payment.id,
        orderId,
        customerId: payment.customer_id,
        io,
        gatewayPaymentId: gatewayPaymentIdFromApi,
      });

      status = 'SUCCESS';
      gatewayPaymentId = gatewayPaymentIdFromApi;
      orderStatus = 'CONFIRMED';
      return true;
    };

    if (status === 'PENDING' || status === 'INITIATED') {
      const liveStatus = await cashfreeService.getOrderStatus(String(orderId));
      const liveMapped = mapCashfreeOrderStatus(liveStatus.order_status);
      paymentSessionId = liveStatus.payment_session_id || paymentSessionId;

      if (liveMapped === 'SUCCESS') {
        await confirmIfPaidAtGateway();
      } else {
        status = liveMapped;
      }
    } else if (status === 'SUCCESS' && UNCONFIRMED_ORDER_STATUSES.has(orderStatus)) {
      await applyPaymentSuccess(client, {
        paymentId: payment.id,
        orderId,
        customerId: payment.customer_id,
        io,
      });
      orderStatus = 'CONFIRMED';
    }

    await client.query('COMMIT');

    return ok(
      res,
      {
        status,
        orderStatus,
        gateway_order_id: payment.gateway_order_id,
        gateway_payment_id: gatewayPaymentId,
        payment_session_id: paymentSessionId,
      },
      'Payment status retrieved'
    );
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore rollback errors */
    }
    logger.error('cashfree_status_check_failed', { orderId, error: error.message });
    return fail(res, 500, 'Status check failed');
  } finally {
    client.release();
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
      `SELECT pt.id, pt.order_id, pt.status, pt.amount, pt.gateway_order_id, pt.gateway_response,
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
      const io = req.app.get('io');
      await applyPaymentSuccess(client, {
        paymentId: payment.id,
        orderId: payment.order_id,
        customerId: payment.customer_id,
        io,
      });
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

    const receivedAmount =
      successfulPayment.payment_amount != null
        ? successfulPayment.payment_amount
        : successfulPayment.order_amount;

    if (isAmountMismatch(payment.amount, receivedAmount)) {
      reportAmountMismatch({
        paymentId: payment.id,
        orderId: payment.order_id,
        expectedAmount: payment.amount,
        receivedAmount,
        source: 'verify',
      });
      await client.query('ROLLBACK');
      return fail(res, 400, 'Amount mismatch');
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

/**
 * @route POST /api/payments/cashfree/abandon
 * User dismissed Cashfree checkout — order stays PLACED for retry.
 */
const abandonPayment = async (req, res) => {
  const orderId = Number(req.body?.orderId);
  const reasonRaw = String(req.body?.reason || 'user_abandoned').trim();
  const reason = reasonRaw.slice(0, 64) || 'user_abandoned';

  if (!Number.isInteger(orderId) || orderId <= 0) {
    return fail(res, 400, 'Order ID is required');
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    const orderResult = await client.query(
      `SELECT id, customer_id, status, payment_mode, payment_status
       FROM orders
       WHERE id = $1 AND customer_id = $2
       FOR UPDATE`,
      [orderId, req.user.id]
    );

    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return fail(res, 404, 'Order not found or access denied');
    }

    const order = orderResult.rows[0];

    if (order.payment_mode !== 'ONLINE') {
      await client.query('ROLLBACK');
      return fail(res, 400, 'Order is not configured for online payment');
    }

    if (!UNCONFIRMED_ORDER_STATUSES.has(order.status)) {
      await client.query('ROLLBACK');
      return fail(
        res,
        400,
        `Order payment cannot be abandoned. Current status: ${order.status}`
      );
    }

    const paymentResult = await client.query(
      `SELECT id, status
       FROM payment_transactions
       WHERE order_id = $1 AND gateway = 'CASHFREE'
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [orderId]
    );

    const payment = paymentResult.rows[0];
    const io = req.app.get('io');

    if (payment?.status === 'SUCCESS') {
      await client.query('ROLLBACK');
      return ok(
        res,
        { orderId, paymentStatus: 'PAID', alreadyPaid: true },
        'Payment already completed'
      );
    }

    const definitiveFailureReasons = new Set([
      'payment_failed',
      'payment_declined',
      'sdk_error',
      'network_error',
    ]);
    const isDefinitiveFailure = definitiveFailureReasons.has(reason);

    if (payment?.status === 'FAILED' && !isDefinitiveFailure) {
      await client.query(
        `UPDATE orders
         SET payment_status = 'FAILED', updated_at = NOW()
         WHERE id = $1`,
        [orderId]
      );
      await client.query('COMMIT');
      return ok(
        res,
        {
          orderId,
          paymentStatus: 'FAILED',
          orderStatus: order.status,
        },
        'Payment already abandoned'
      );
    }

    if (isDefinitiveFailure) {
      if (payment?.id) {
        await applyPaymentFailure(client, {
          paymentId: payment.id,
          orderId,
          customerId: order.customer_id,
          io,
        });
      } else {
        await client.query(
          `UPDATE orders
           SET status = 'CANCELLED', payment_status = 'FAILED', updated_at = NOW()
           WHERE id = $1`,
          [orderId]
        );
      }
      await client.query('COMMIT');
      return ok(
        res,
        {
          orderId,
          paymentStatus: 'FAILED',
          orderStatus: 'CANCELLED',
        },
        'Payment failed — order cancelled'
      );
    }

    await applyPaymentAbandon(client, {
      paymentId: payment?.id ?? null,
      orderId,
      customerId: order.customer_id,
      io,
      reason,
    });

    await client.query('COMMIT');

    return ok(
      res,
      {
        orderId,
        paymentStatus: 'FAILED',
        orderStatus: order.status,
      },
      'Payment abandoned'
    );
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore rollback errors */
    }
    logger.error('cashfree_abandon_failed', { orderId, error: error.message });
    return fail(res, 500, 'Failed to record payment abandonment');
  } finally {
    client.release();
  }
};

module.exports = {
  initiatePayment,
  handleWebhook,
  getPaymentStatus,
  verifyPayment,
  abandonPayment,
  resolveSuccessfulCashfreePayment,
};
