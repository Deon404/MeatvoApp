const asyncHandler = require('express-async-handler');
const axios = require('axios');
const {
  generateChecksum,
  verifyChecksum,
  parsePhonePeWebhookBody,
} = require('../../utils/phonepeChecksum');
const { query, getClient } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const { paymentLogger } = require('./secure-logger');
const { reserveStockForPaidOrder } = require('./payment-stock');
const { notifyStaffNewOrder } = require('../../services/notification.service');
const { cancelOrderForPaymentFailure } = require('../../services/payment-reconciliation.service');
const { emitOrderLifecycleEvent } = require('../../utils/orderSocketEmit');
const cashfreeController = require('./cashfree.controller');

// PhonePe configuration
const PHONEPE_API_BASE = process.env.PHONEPE_API_BASE || 'https://api.phonepe.com/v1';
const PHONEPE_MERCHANT_ID = process.env.PHONEPE_MERCHANT_ID;
const PHONEPE_SALT_KEY = process.env.PHONEPE_SALT_KEY;
const PHONEPE_SALT_INDEX = process.env.PHONEPE_SALT_INDEX || '1';
const PHONEPE_REDIRECT_URL = process.env.PHONEPE_REDIRECT_URL;
const PHONEPE_WEBHOOK_URL = process.env.PHONEPE_WEBHOOK_URL;

const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';

if (!PHONEPE_MERCHANT_ID || !PHONEPE_SALT_KEY) {
  logger.warn('phonepe_config_missing', {
    merchantId: PHONEPE_MERCHANT_ID ? 'configured' : 'missing',
    saltKey: PHONEPE_SALT_KEY ? 'configured' : 'missing',
  });
}

if (isProd && (!PHONEPE_REDIRECT_URL || !PHONEPE_WEBHOOK_URL)) {
  logger.warn('phonepe_redirect_webhook_missing', {
    redirectUrl: PHONEPE_REDIRECT_URL ? 'configured' : 'missing',
    webhookUrl: PHONEPE_WEBHOOK_URL ? 'configured' : 'missing',
  });
}

const buildChecksum = (payload) =>
  generateChecksum(payload, PHONEPE_SALT_KEY, PHONEPE_SALT_INDEX);

const verifyWebhookSignature = (payload, signature) =>
  verifyChecksum(payload, signature, PHONEPE_SALT_KEY, PHONEPE_SALT_INDEX);

/**
 * Create PhonePe payment request
 */
const createPhonePePayment = async (orderId, amount, customerPhone, customerEmail = null, idempotencyKey = null) => {
  if (!PHONEPE_MERCHANT_ID || !PHONEPE_SALT_KEY) {
    return { success: false, error: 'PhonePe not configured — use CashFree' };
  }

  const transactionId = idempotencyKey
    ? `TXN_${idempotencyKey}_${Date.now()}`
    : `TXN_${orderId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  
  const paymentPayload = {
    merchantId: PHONEPE_MERCHANT_ID,
    merchantTransactionId: transactionId,
    amount: Math.round(amount * 100), // Convert to paise
    redirectUrl: PHONEPE_REDIRECT_URL,
    redirectMode: 'REDIRECT',
    callbackUrl: PHONEPE_WEBHOOK_URL,
    paymentInstrument: {
      type: 'PAY_PAGE'
    },
    merchantUserId: customerPhone,
    email: customerEmail,
    mobileNumber: customerPhone
  };

  const payload = Buffer.from(JSON.stringify(paymentPayload)).toString('base64');
  const checksum = buildChecksum(payload);

  try {
    const response = await axios.post(`${PHONEPE_API_BASE}/pg/v1/pay`, {
      request: payload
    }, {
      headers: {
        'Content-Type': 'application/json',
        'X-VERIFY': checksum,
        'X-MERCHANT-ID': PHONEPE_MERCHANT_ID,
        Accept: 'application/json',
      },
      timeout: 30000,
    });

    if (response.data.success) {
      return {
        success: true,
        data: {
          transactionId,
          paymentUrl: response.data.data.instrumentResponse.redirectInfo.url,
          merchantTransactionId: transactionId
        }
      };
    } else {
      logger.error('PhonePe payment initiation failed', response.data);
      return {
        success: false,
        error: response.data.message || 'Payment initiation failed'
      };
    }
  } catch (error) {
    logger.error('PhonePe API error', { 
      error: error.message, 
      orderId, 
      amount 
    });
    return {
      success: false,
      error: 'Payment service unavailable'
    };
  }
};

/**
 * Check payment status
 */
const checkPaymentStatus = async (merchantTransactionId) => {
  if (!PHONEPE_MERCHANT_ID || !PHONEPE_SALT_KEY) {
    return { success: false, error: 'PhonePe is not configured' };
  }

  const payload = `/pg/v1/status/${PHONEPE_MERCHANT_ID}/${merchantTransactionId}`;
  const checksum = buildChecksum(payload);

  try {
    const response = await axios.get(`${PHONEPE_API_BASE}${payload}`, {
      headers: {
        'Content-Type': 'application/json',
        'X-VERIFY': checksum,
        'X-MERCHANT-ID': PHONEPE_MERCHANT_ID,
        Accept: 'application/json',
      },
      timeout: 15000,
    });

    if (response.data.success) {
      return {
        success: true,
        data: response.data.data
      };
    } else {
      return {
        success: false,
        error: response.data.message || 'Status check failed'
      };
    }
  } catch (error) {
    logger.error('PhonePe status check error', { 
      error: error.message, 
      merchantTransactionId 
    });
    return {
      success: false,
      error: 'Status check failed'
    };
  }
};

/**
 * Initiate payment for an order (delegates to CashFree)
 */
const initiatePayment = asyncHandler(async (req, res) => {
  return cashfreeController.initiatePayment(req, res);
});

/**
 * Check payment status
 */
const getPaymentStatus = asyncHandler(async (req, res) => {
  const { orderId } = req.validated.params;

  if (!orderId) {
    return fail(res, 400, 'Order ID is required');
  }

  try {
    const isAdmin = req.user.role === 'admin';

    // Fetch payment transaction (scoped to owner unless admin)
    const paymentResult = await query(
      `SELECT pt.id, pt.order_id, pt.status, pt.gateway_transaction_id, pt.gateway_response, pt.created_at,
              o.customer_id, o.total_amount, o.status as order_status
       FROM payment_transactions pt
       JOIN orders o ON pt.order_id = o.id
       WHERE pt.order_id = $1${isAdmin ? '' : ' AND o.customer_id = $2'}
       ORDER BY pt.created_at DESC
       LIMIT 1`,
      isAdmin ? [orderId] : [orderId, req.user.id]
    );

    if (paymentResult.rows.length === 0) {
      return fail(res, 404, 'Payment not found');
    }

    const payment = paymentResult.rows[0];

    // If payment is still pending, check with PhonePe
    if (payment.status === 'PENDING' && payment.gateway_transaction_id) {
      const statusResponse = await checkPaymentStatus(payment.gateway_transaction_id);

      if (statusResponse.success) {
        const phonePeData = statusResponse.data;
        let newStatus = 'PENDING';

        if (phonePeData.state === 'COMPLETED') {
          newStatus = 'SUCCESS';
        } else if (phonePeData.state === 'FAILED') {
          newStatus = 'FAILED';
        } else if (phonePeData.state === 'PENDING') {
          newStatus = 'PENDING';
        }

        // Update payment status if changed
        if (newStatus !== payment.status) {
          await query(
            `UPDATE payment_transactions 
             SET status = $1, gateway_response = $2, updated_at = NOW()
             WHERE id = $3`,
            [newStatus, JSON.stringify(phonePeData), payment.id]
          );

          // If payment successful, update order status
          if (newStatus === 'SUCCESS') {
            const client = await getClient();
            try {
              await client.query('BEGIN');
              await reserveStockForPaidOrder(client, orderId);
              await client.query(
                `UPDATE orders 
                 SET status = 'CONFIRMED', payment_status = 'PAID', updated_at = NOW()
                 WHERE id = $1`,
                [orderId]
              );
              await client.query('COMMIT');
            } catch (stockError) {
              await client.query('ROLLBACK');
              throw stockError;
            } finally {
              client.release();
            }

            logger.info('Payment completed via status check', {
              orderId,
              paymentId: payment.id,
              transactionId: payment.gateway_transaction_id,
              amount: payment.total_amount
            });

            // Check for existing assignment to prevent double-assignment
            const existingAssignment = await query(
              `SELECT id FROM order_assignments 
               WHERE order_id = $1 
               AND status NOT IN ('cancelled', 'expired', 'rejected')
               LIMIT 1`,
              [orderId]
            );

            if (!existingAssignment.rows.length) {
              const io = req.app.get('io');
              if (io) {
                io.to(`customer_${payment.customer_id}`).emit('order:status_updated', {
                  orderId,
                  status: 'CONFIRMED',
                  message: 'Your order is confirmed — preparing now',
                });
              }
            }
          }

          // LIFECYCLE FIX: cancel order when PhonePe reports failure via status poll
          if (newStatus === 'FAILED') {
            const io = req.app.get('io');
            await cancelOrderForPaymentFailure(orderId, payment.customer_id, io);
          }

          payment.status = newStatus;
          payment.gateway_response = phonePeData;
        }
      }
    }

    return ok(res, {
      paymentId: payment.id,
      orderId: payment.order_id,
      status: payment.status,
      gatewayTransactionId: payment.gateway_transaction_id,
      amount: payment.total_amount,
      orderStatus: payment.order_status,
      gatewayResponse: payment.gateway_response,
      createdAt: payment.created_at
    }, 'Payment status retrieved');

  } catch (error) {
    paymentLogger.payment.statusCheckFailed(logger, {
      orderId,
      error: error.message
    });
    return fail(res, 500, 'Status check failed');
  }
});

/**
 * Handle PhonePe webhook
 */
const handlePhonePeWebhook = asyncHandler(async (req, res) => {
  const signature = req.headers['x-verify'];
  const rawBody = req.body;
  const clientIP = req.ip || req.connection.remoteAddress;
  const userAgent = req.headers['user-agent'];

  const { payloadForSignature, webhookBody, legacyRejected } = parsePhonePeWebhookBody(rawBody);

  if (legacyRejected) {
    paymentLogger.webhook.signatureInvalid(logger, {
      clientIP,
      userAgent,
      reason: 'legacy_format_rejected',
    });
    return fail(res, 400, 'Legacy webhook format not accepted in production');
  }

  // Log incoming webhook for security monitoring
  paymentLogger.webhook.received(logger, {
    clientIP,
    hasSignature: !!signature,
    merchantTransactionId: webhookBody?.data?.merchantTransactionId,
    code: webhookBody?.code,
  });

  if (!signature) {
    paymentLogger.webhook.signatureInvalid(logger, {
      clientIP,
      userAgent,
      merchantTransactionId: webhookBody?.data?.merchantTransactionId,
    });
    return fail(res, 400, 'Signature missing');
  }

  if (!payloadForSignature || !verifyWebhookSignature(payloadForSignature, signature)) {
    paymentLogger.webhook.signatureInvalid(logger, {
      clientIP,
      userAgent,
      merchantTransactionId: webhookBody?.data?.merchantTransactionId,
    });
    return fail(res, 401, 'Invalid signature');
  }

  // Validate webhook body structure
  if (!webhookBody || typeof webhookBody !== 'object') {
    paymentLogger.webhook.dataMissing(logger, {
      clientIP,
      userAgent,
      code: webhookBody?.code
    });
    return fail(res, 400, 'Invalid webhook body');
  }

  const { code, data } = webhookBody;

  // Strict validation of webhook codes
  const validCodes = ['PAYMENT_SUCCESS', 'PAYMENT_FAILED', 'PAYMENT_REFUNDED'];
  if (!validCodes.includes(code)) {
    paymentLogger.webhook.codeInvalid(logger, {
      clientIP,
      userAgent,
      code
    });
    return fail(res, 400, 'Invalid webhook code');
  }

  // Validate required data fields
  if (!data || !data.merchantTransactionId || !data.transactionId || data.amount === undefined) {
    paymentLogger.webhook.dataMissing(logger, {
      clientIP,
      userAgent,
      code
    });
    return fail(res, 400, 'Missing required data fields');
  }

  const { merchantTransactionId, transactionId, amount } = data;

  try {
    // Start database transaction for atomic webhook processing
    const client = await getClient();
    
    try {
      await client.query('BEGIN');
      
      // Find payment transaction with row lock
      const paymentResult = await client.query(
        `SELECT pt.id, pt.order_id, pt.amount, pt.status, pt.gateway_response, 
                o.customer_id, o.status as order_status, o.total_amount
         FROM payment_transactions pt
         JOIN orders o ON pt.order_id = o.id
         WHERE pt.gateway_transaction_id = $1 FOR UPDATE`,
        [merchantTransactionId]
      );

      if (paymentResult.rows.length === 0) {
        paymentLogger.webhook.transactionUnknown(logger, {
          clientIP,
          userAgent,
          merchantTransactionId
        });
        await client.query('ROLLBACK');
        client.release();
        return ok(res, {}, 'Webhook processed'); // Return 200 to avoid retry loops
      }

      const payment = paymentResult.rows[0];

      // Validate order exists and is accessible
      if (!payment.order_id || !payment.customer_id) {
        paymentLogger.webhook.dataMissing(logger, {
          clientIP,
          userAgent,
          code
        });
        await client.query('ROLLBACK');
        client.release();
        return ok(res, {}, 'Webhook processed');
      }

      // Verify amount to prevent fraud
      const expectedAmount = payment.amount * 100; // Convert to paise
      if (amount !== expectedAmount) {
        paymentLogger.webhook.amountMismatch(logger, {
          clientIP,
          userAgent,
          merchantTransactionId,
          expected: expectedAmount,
          received: amount
        });
        await client.query('ROLLBACK');
        client.release();
        return fail(res, 400, 'Amount mismatch');
      }

      // Enhanced idempotency check - reject any webhook for already processed payments
      if (payment.status !== 'INITIATED' && payment.status !== 'PENDING') {
        paymentLogger.webhook.duplicateProcessed(logger, {
          clientIP,
          userAgent,
          paymentId: payment.id,
          currentStatus: payment.status,
          webhookCode: code,
          merchantTransactionId
        });
        await client.query('ROLLBACK');
        client.release();
        return ok(res, {}, 'Webhook processed'); // Return 200 to avoid retry loops
      }

      // Additional validation: Check if webhook code makes sense for current payment status
      if (payment.status === 'INITIATED' && code !== 'PAYMENT_SUCCESS' && code !== 'PAYMENT_FAILED') {
        paymentLogger.webhook.codeInvalid(logger, {
          clientIP,
          userAgent,
          code
        });
        await client.query('ROLLBACK');
        client.release();
        return fail(res, 400, 'Invalid webhook code for payment status');
      }

      // Update payment transaction based on webhook code
      let paymentStatus = 'PENDING';
      let orderStatus = payment.order_status || 'PLACED';
      let paymentStatusField = 'PENDING';

      switch (code) {
        case 'PAYMENT_SUCCESS':
          paymentStatus = 'SUCCESS';
          orderStatus = 'CONFIRMED';
          paymentStatusField = 'PAID';
          break;
        case 'PAYMENT_FAILED':
          paymentStatus = 'FAILED';
          orderStatus = payment.order_status || 'PLACED';
          paymentStatusField = 'FAILED';
          break;
        case 'PAYMENT_REFUNDED':
          paymentStatus = 'REFUNDED';
          paymentStatusField = 'REFUNDED';
          // Order status remains CONFIRMED for refunds
          if (payment.order_status === 'PLACED') {
            orderStatus = 'CONFIRMED'; // Move to confirmed if still placed
          }
          break;
        default:
          paymentLogger.webhook.codeInvalid(logger, {
            clientIP,
            userAgent,
            code
          });
          await client.query('ROLLBACK');
          client.release();
          return fail(res, 400, 'Unhandled webhook code');
      }

      // Update payment transaction
      await client.query(
        `UPDATE payment_transactions 
         SET status = $1, gateway_transaction_id = $2, gateway_response = $3, updated_at = NOW()
         WHERE id = $4`,
        [paymentStatus, transactionId, JSON.stringify(data), payment.id]
      );

      // Update order state if needed
      if (code === 'PAYMENT_SUCCESS') {
        await reserveStockForPaidOrder(client, payment.order_id);
        await client.query(
          `UPDATE orders 
           SET status = $1, payment_status = $2, updated_at = NOW()
           WHERE id = $3`,
          [orderStatus, paymentStatusField, payment.order_id]
        );
      } else if (code === 'PAYMENT_FAILED') {
        // LIFECYCLE FIX: auto-cancel unpaid online orders on payment failure
        await client.query(
          `UPDATE orders 
           SET status = 'CANCELLED', payment_status = $1, updated_at = NOW()
           WHERE id = $2 AND status IN ('PLACED', 'PAYMENT_PENDING', 'CONFIRMED')`,
          [paymentStatusField, payment.order_id]
        );
      } else if (code === 'PAYMENT_REFUNDED') {
        await client.query(
          `UPDATE orders 
           SET payment_status = $1, updated_at = NOW()
           WHERE id = $2`,
          [paymentStatusField, payment.order_id]
        );
      }

      // Commit transaction
      await client.query('COMMIT');
      client.release();

      if (code === 'PAYMENT_SUCCESS') {
        const io = req.app.get('io');
        if (io) {
          const payload = {
            orderId: payment.order_id,
            customerId: payment.customer_id,
            totalAmount: Number(payment.total_amount || 0),
            createdAt: new Date().toISOString(),
          };
          io.to('admin_room').emit('order:new', payload);
          io.to('staff_room').emit('order:new', payload);
          await notifyStaffNewOrder({
            orderId: payment.order_id,
            totalAmount: Number(payment.total_amount || 0),
            io,
          });
        }

        // Check for existing assignment to prevent double-assignment
        const existingAssignment = await query(
          `SELECT id FROM order_assignments 
           WHERE order_id = $1 
           AND status NOT IN ('cancelled', 'expired', 'rejected')
           LIMIT 1`,
          [payment.order_id]
        );

        if (!existingAssignment.rows.length) {
          if (io) {
            io.to(`customer_${payment.customer_id}`).emit('order:status_updated', {
              orderId: payment.order_id,
              status: 'CONFIRMED',
              message: 'Your order is confirmed — preparing now',
            });
          }
        }
      } else if (code === 'PAYMENT_FAILED') {
        const io = req.app.get('io');
        emitOrderLifecycleEvent(io, {
          orderId: payment.order_id,
          customerId: payment.customer_id,
          payload: {
            orderId: payment.order_id,
            status: 'CANCELLED',
            reason: 'payment_failed',
            updatedAt: new Date().toISOString(),
          },
        });
      }

      paymentLogger.webhook.processed(logger, {
        orderId: payment.order_id,
        paymentId: payment.id,
        merchantTransactionId,
        transactionId,
        code,
        paymentStatus,
        clientIP
      });

      return ok(res, {}, 'Webhook processed successfully');

    } catch (error) {
      await client.query('ROLLBACK');
      client.release();
      throw error;
    }
  } catch (error) {
    paymentLogger.webhook.processingError(logger, {
      clientIP,
      userAgent,
      error: error.message,
      merchantTransactionId
    });
    return fail(res, 500, 'Webhook processing failed');
  }
});

module.exports = {
  initiatePayment,
  getPaymentStatus,
  handlePhonePeWebhook,
  paymentLogger,
};
