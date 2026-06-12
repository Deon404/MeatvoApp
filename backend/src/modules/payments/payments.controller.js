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
const { assignOrderToPartner } = require('../../services/assignment.service');
const { reserveStockForPaidOrder } = require('./payment-stock');

// PhonePe configuration
const PHONEPE_API_BASE = process.env.PHONEPE_API_BASE || 'https://api.phonepe.com/v1';
const PHONEPE_MERCHANT_ID = process.env.PHONEPE_MERCHANT_ID;
const PHONEPE_SALT_KEY = process.env.PHONEPE_SALT_KEY;
const PHONEPE_SALT_INDEX = process.env.PHONEPE_SALT_INDEX || '1';
const PHONEPE_REDIRECT_URL = process.env.PHONEPE_REDIRECT_URL;
const PHONEPE_WEBHOOK_URL = process.env.PHONEPE_WEBHOOK_URL;

const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';

if (!PHONEPE_MERCHANT_ID || !PHONEPE_SALT_KEY) {
  logger.error('phonepe_config_missing', {
    merchantId: PHONEPE_MERCHANT_ID ? 'configured' : 'missing',
    saltKey: PHONEPE_SALT_KEY ? 'configured' : 'missing',
  });
  if (isProd) {
    throw new Error('PhonePe configuration missing. Set PHONEPE_MERCHANT_ID and PHONEPE_SALT_KEY.');
  }
}

if (isProd && (!PHONEPE_REDIRECT_URL || !PHONEPE_WEBHOOK_URL)) {
  throw new Error('PHONEPE_REDIRECT_URL and PHONEPE_WEBHOOK_URL must be set in production.');
}

const buildChecksum = (payload) =>
  generateChecksum(payload, PHONEPE_SALT_KEY, PHONEPE_SALT_INDEX);

const verifyWebhookSignature = (payload, signature) =>
  verifyChecksum(payload, signature, PHONEPE_SALT_KEY, PHONEPE_SALT_INDEX);

/**
 * Create PhonePe payment request
 */
const createPhonePePayment = async (orderId, amount, customerPhone, customerEmail = null, idempotencyKey = null) => {
  const transactionId = idempotencyKey
    ? `TXN_${idempotencyKey}_${Date.now()}`
    : `TXN_${orderId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  
  const paymentPayload = {
    merchantId: PHONEPE_MERCHANT_ID,
    merchantTransactionId: transactionId,
    amount: amount * 100, // Convert to paise
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
        'X-MERCHANT-ID': PHONEPE_MERCHANT_ID
      }
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
  const payload = `/pg/v1/status/${PHONEPE_MERCHANT_ID}/${merchantTransactionId}`;
  const checksum = buildChecksum(payload);

  try {
    const response = await axios.get(`${PHONEPE_API_BASE}${payload}`, {
      headers: {
        'Content-Type': 'application/json',
        'X-VERIFY': checksum,
        'X-MERCHANT-ID': PHONEPE_MERCHANT_ID
      }
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
 * Initiate payment for an order
 */
const initiatePayment = asyncHandler(async (req, res) => {
  const { orderId } = req.validated.body;

  if (!orderId) {
    return fail(res, 400, 'Order ID is required');
  }

  try {
    // Start database transaction for atomic operations
    const client = await getClient();
    
    try {
      await client.query('BEGIN');
      
      // Fetch order from database with user ownership validation
      const orderResult = await client.query(
        `SELECT o.id, o.customer_id, o.total_amount, o.status, o.payment_mode, u.phone
         FROM orders o 
         JOIN users u ON o.customer_id = u.id 
         WHERE o.id = $1 AND o.customer_id = $2`,
        [orderId, req.user.id]
      );

      if (orderResult.rows.length === 0) {
        await client.query('ROLLBACK');
        client.release();
        return fail(res, 404, 'Order not found or access denied');
      }

      const order = orderResult.rows[0];

      // Validate order status
      if (order.status !== 'PLACED') {
        await client.query('ROLLBACK');
        client.release();
        return fail(res, 400, 'Order cannot be paid for. Current status: ' + order.status);
      }

      // Validate payment mode
      if (order.payment_mode !== 'ONLINE') {
        await client.query('ROLLBACK');
        client.release();
        return fail(res, 400, 'Order is not configured for online payment');
      }

      // Idempotency: orderId is the idempotency key.
      const existingPaymentResult = await client.query(
        `SELECT id, status, payment_url, gateway_transaction_id
         FROM payment_transactions
         WHERE order_id = $1 AND status IN ($2, $3, $4)
         ORDER BY created_at DESC
         LIMIT 1
         FOR UPDATE`,
        [orderId, 'PENDING', 'INITIATED', 'SUCCESS']
      );

      if (existingPaymentResult.rows.length > 0) {
        const existing = existingPaymentResult.rows[0];
        await client.query('COMMIT');
        client.release();
        return ok(
          res,
          {
            paymentId: existing.id,
            paymentUrl: existing.payment_url || null,
            transactionId: existing.gateway_transaction_id || null,
            amount: Number(order.total_amount),
            idempotent: true,
          },
          'Existing payment reused'
        );
      }

      // Create payment transaction record
      const paymentResult = await client.query(
        `INSERT INTO payment_transactions (order_id, amount, status, gateway, gateway_transaction_id, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())
         RETURNING id`,
        [orderId, order.total_amount, 'INITIATED', 'PHONEPE', null]
      );

      const paymentId = paymentResult.rows[0].id;

      // Initiate PhonePe payment
      const paymentResponse = await createPhonePePayment(
        orderId,
        order.total_amount,
        order.phone,
        null,
        String(orderId)
      );

      if (!paymentResponse.success) {
        // Update payment transaction as failed
        await client.query(
          'UPDATE payment_transactions SET status = $1, gateway_response = $2 WHERE id = $3',
          ['FAILED', JSON.stringify(paymentResponse.error), paymentId]
        );
        await client.query('ROLLBACK');
        client.release();
        
        paymentLogger.payment.initiationFailed(logger, {
          orderId,
          userId: req.user.id,
          error: paymentResponse.error
        });
        
        logger.error('Payment initiation gateway error:', paymentResponse.error);
        return fail(res, 500, 'Payment initiation failed');
      }

      // Update payment transaction with gateway details
      await client.query(
        `UPDATE payment_transactions 
         SET status = $1, gateway_transaction_id = $2, payment_url = $3, gateway_response = $4
         WHERE id = $5`,
        [
          'PENDING',
          paymentResponse.data.transactionId,
          paymentResponse.data.paymentUrl,
          JSON.stringify(paymentResponse.data),
          paymentId
        ]
      );

      // Commit transaction
      await client.query('COMMIT');
      client.release();

      paymentLogger.payment.initiated(logger, {
        orderId,
        paymentId,
        transactionId: paymentResponse.data.transactionId,
        amount: order.total_amount,
        userId: req.user.id
      });

      return ok(res, {
        paymentId,
        paymentUrl: paymentResponse.data.paymentUrl,
        transactionId: paymentResponse.data.transactionId,
        amount: order.total_amount
      }, 'Payment initiated successfully');

    } catch (error) {
      await client.query('ROLLBACK');
      client.release();
      throw error;
    }
  } catch (error) {
    paymentLogger.payment.initiationFailed(logger, {
      orderId,
      userId: req.user?.id,
      error: error.message
    });
    return fail(res, 500, 'Payment initiation failed');
  }
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
                  message: 'Payment confirmed! Finding delivery partner...',
                });
              }
              assignOrderToPartner({ orderId, io }).catch(err =>
                logger.error('Post-payment auto-assign failed (status-check):', err));
            }
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

  const { payloadForSignature, webhookBody } = parsePhonePeWebhookBody(rawBody);

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
        await client.query(
          `UPDATE orders 
           SET payment_status = $1, updated_at = NOW()
           WHERE id = $2`,
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
          io.to('admin_room').emit('order:new', {
            orderId: payment.order_id,
            customerId: payment.customer_id,
            totalAmount: Number(payment.total_amount || 0),
            createdAt: new Date().toISOString(),
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
              message: 'Payment confirmed! Finding delivery partner...',
            });
          }
          // Trigger assignment after payment confirmed
          assignOrderToPartner({ orderId: payment.order_id, io }).catch(err =>
            logger.error('Post-payment auto-assign failed (webhook):', err));
        }
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
  handlePhonePeWebhook
};
