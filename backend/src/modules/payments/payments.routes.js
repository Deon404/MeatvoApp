const express = require('express');
const rateLimit = require('express-rate-limit');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { initiatePayment, getPaymentStatus, handlePhonePeWebhook } = require('./payments.controller');
const { initiatePaymentSchema, getPaymentStatusSchema } = require('./payments.validation');

// Rate limiting for payment initiation (per user)
const paymentRateLimit = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // limit each user to 10 payment initiations per minute
  keyGenerator: (req) => req.user?.id || 'anonymous',
  message: {
    error: 'Too many payment attempts',
    retryAfter: '1 minute'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    const { paymentLogger } = require('./payments.controller');
    const logger = require('../../utils/logger');
    
    paymentLogger.security.rateLimitExceeded(logger, {
      clientIP: req.ip,
      userAgent: req.headers['user-agent'],
      endpoint: '/api/payments/phonepe/initiate'
    });
    
    res.status(429).json({
      error: 'Too many payment attempts',
      retryAfter: '1 minute'
    });
  }
});

// Rate limiting for webhook endpoint (production optimized)
const webhookRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many webhook requests',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true // Only count failed requests
});

// Protected payment routes
router.post('/phonepe/initiate', protect, validate(initiatePaymentSchema), paymentRateLimit, initiatePayment);
router.post('/initiate', protect, validate(initiatePaymentSchema), paymentRateLimit, initiatePayment);
router.get('/:orderId/status', protect, validate(getPaymentStatusSchema), getPaymentStatus);

// Public webhook route with rate limiting
router.post('/phonepe/webhook', webhookRateLimit, handlePhonePeWebhook);
router.post('/webhook', webhookRateLimit, handlePhonePeWebhook);

module.exports = router;
