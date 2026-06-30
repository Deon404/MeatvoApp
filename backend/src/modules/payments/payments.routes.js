const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { initiatePayment, handlePhonePeWebhook } = require('./payments.controller');
const cashfreeController = require('./cashfree.controller');
const paymentSecurity = require('../../security/payment.security');
const {
  initiatePaymentSchema,
  getPaymentStatusSchema,
  verifyPaymentSchema,
} = require('./payments.validation');

const { fail } = require('../../utils/response');

// Rate limiting for payment initiation (per user)
const paymentRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  // Protected route — req.user.id is always set by protect middleware
  keyGenerator: (req) => String(req.user?.id || 'anonymous'),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: (req, res) => {
    const { paymentLogger } = require('./payments.controller');
    const { logger } = require('../../utils/logger');
    paymentLogger.security.rateLimitExceeded(logger, {
      clientIP: req.ip,
      userAgent: req.headers['user-agent'],
      endpoint: '/api/payments/phonepe/initiate',
    });
    return fail(res, 429, 'Too many payment attempts', { code: 'RATE_LIMITED', retryAfter: '1 minute' });
  },
});

// Rate limiting for webhook endpoint
const webhookRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  handler: (req, res) => {
    return fail(res, 429, 'Too many webhook requests', { code: 'RATE_LIMITED' });
  },
});

// Protected payment routes
router.post('/phonepe/initiate', protect, validate(initiatePaymentSchema), paymentRateLimit, initiatePayment);
router.post('/initiate', protect, validate(initiatePaymentSchema), paymentRateLimit, initiatePayment);
router.post('/verify', protect, validate(verifyPaymentSchema), paymentRateLimit, cashfreeController.verifyPayment);
router.post('/phonepe/verify', protect, validate(verifyPaymentSchema), paymentRateLimit, cashfreeController.verifyPayment);

router.post('/cashfree/initiate', protect, paymentRateLimit, paymentSecurity.fraudDetection.bind(paymentSecurity), cashfreeController.initiatePayment);
router.post('/cashfree/abandon', protect, paymentRateLimit, cashfreeController.abandonPayment);
router.post('/cashfree/webhook', webhookRateLimit, cashfreeController.handleWebhook);
router.get('/cashfree/:orderId/status', protect, paymentRateLimit, cashfreeController.getPaymentStatus);
router.post('/cashfree/verify', protect, paymentRateLimit, cashfreeController.verifyPayment);

router.get('/:orderId/status', protect, validate(getPaymentStatusSchema), paymentRateLimit, cashfreeController.getPaymentStatus);

// Public webhook route with rate limiting
router.post('/phonepe/webhook', webhookRateLimit, handlePhonePeWebhook);
router.post('/webhook', webhookRateLimit, handlePhonePeWebhook);

module.exports = router;
