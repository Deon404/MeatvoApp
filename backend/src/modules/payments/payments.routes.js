const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { paymentLogger } = require('./secure-logger');
const cashfreeController = require('./cashfree.controller');
const paymentSecurity = require('../../security/payment.security');
const {
  initiatePaymentSchema,
  getPaymentStatusSchema,
  verifyPaymentSchema,
} = require('./payments.validation');

const { fail } = require('../../utils/response');

const phonePeRetired = (req, res) =>
  fail(res, 410, 'PhonePe is retired for the MVP release. Use Cashfree payment endpoints.', {
    supportedGateway: 'CASHFREE',
    canonicalEndpoints: {
      initiate: '/api/payments/cashfree/initiate',
      verify: '/api/payments/cashfree/verify',
      webhook: '/api/payments/cashfree/webhook',
    },
  });

// Rate limiting for payment initiation (per user)
const paymentRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  // Protected route — req.user.id is always set by protect middleware
  keyGenerator: (req) => String(req.user?.id || 'anonymous'),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: (req, res) => {
    const { logger } = require('../../utils/logger');
    paymentLogger.security.rateLimitExceeded(logger, {
      clientIP: req.ip,
      userAgent: req.headers['user-agent'],
      endpoint: req.originalUrl || '/api/payments/cashfree/initiate',
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

// Cashfree is the canonical online payment gateway for the MVP release.
router.post('/cashfree/initiate', protect, validate(initiatePaymentSchema), paymentRateLimit, paymentSecurity.fraudDetection.bind(paymentSecurity), cashfreeController.initiatePayment);
router.post('/cashfree/abandon', protect, paymentRateLimit, cashfreeController.abandonPayment);
router.post('/cashfree/webhook', webhookRateLimit, cashfreeController.handleWebhook);
router.get('/cashfree/:orderId/status', protect, validate(getPaymentStatusSchema), paymentRateLimit, cashfreeController.getPaymentStatus);
router.post('/cashfree/verify', protect, validate(verifyPaymentSchema), paymentRateLimit, cashfreeController.verifyPayment);

// Generic aliases kept only as wrappers for older clients.
router.post('/initiate', protect, validate(initiatePaymentSchema), paymentRateLimit, paymentSecurity.fraudDetection.bind(paymentSecurity), cashfreeController.initiatePayment);
router.post('/verify', protect, validate(verifyPaymentSchema), paymentRateLimit, cashfreeController.verifyPayment);
router.get('/:orderId/status', protect, validate(getPaymentStatusSchema), paymentRateLimit, cashfreeController.getPaymentStatus);

// Retired PhonePe/webhook aliases stay explicit so stale clients fail loudly.
router.post('/phonepe/initiate', phonePeRetired);
router.post('/phonepe/verify', phonePeRetired);
router.post('/phonepe/webhook', webhookRateLimit, phonePeRetired);
router.post('/webhook', webhookRateLimit, phonePeRetired);

module.exports = router;
