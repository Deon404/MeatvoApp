// Enhanced Rate Limiting for OTP
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('../db/redis');

// OTP Rate Limiting per phone number
const otpRateLimit = rateLimit({
  store: new RedisStore({
    sendCommand: (...args) => redis.call(...args),
  }),
  keyGenerator: (req) => `otp:${req.body?.phone || req.ip}`,
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3, // Maximum 3 OTP requests per phone per 15 minutes
  message: {
    success: false,
    error: {
      message: 'Too many OTP requests. Please try again after 15 minutes.',
      code: 'OTP_RATE_LIMIT_EXCEEDED'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Verify OTP Rate Limiting per phone
const verifyOtpRateLimit = rateLimit({
  store: new RedisStore({
    sendCommand: (...args) => redis.call(...args),
  }),
  keyGenerator: (req) => `verify:${req.body?.phone || req.ip}`,
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 5, // Maximum 5 verification attempts per phone per 5 minutes
  message: {
    success: false,
    error: {
      message: 'Too many verification attempts. Please try again after 5 minutes.',
      code: 'VERIFY_RATE_LIMIT_EXCEEDED'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Global API Rate Limiting
const globalRateLimit = rateLimit({
  store: new RedisStore({
    sendCommand: (...args) => redis.call(...args),
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Maximum 1000 requests per IP per 15 minutes
  message: {
    success: false,
    error: {
      message: 'Too many requests. Please try again later.',
      code: 'GLOBAL_RATE_LIMIT_EXCEEDED'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Auth Routes Rate Limiting (more strict)
const authRoutesRateLimit = rateLimit({
  store: new RedisStore({
    sendCommand: (...args) => redis.call(...args),
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 50, // Maximum 50 auth requests per IP per 15 minutes
  message: {
    success: false,
    error: {
      message: 'Too many authentication attempts. Please try again later.',
      code: 'AUTH_RATE_LIMIT_EXCEEDED'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  otpRateLimit,
  verifyOtpRateLimit,
  globalRateLimit,
  authRoutesRateLimit
};
