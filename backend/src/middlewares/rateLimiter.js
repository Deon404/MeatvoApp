const redis = require('../db/redis');
const rateLimit = require('express-rate-limit');
const { logger } = require('../utils/logger');
const { fail } = require('../utils/response');

const isProduction = process.env.NODE_ENV === 'production';
const disableApiRateLimit =
  process.env.DISABLE_API_RATE_LIMIT === 'true' || !isProduction;

// Max 10 requests per phone per 10 minutes (development-friendly)
const otpRateLimiter = async (req, res, next) => {
  const phone = req.validated?.body?.phone || req.body?.phone;
  if (!phone || typeof phone !== 'string') return next();

  const key = `rl:otp:${phone}`;

  try {
    const count = await redis.incr(key);
    if (count === 1) {
      await redis.expire(key, 10 * 60);
    }

    if (count > 10) {
      return fail(res, 429, 'Too many OTP requests. Try again later.');
    }

    return next();
  } catch (redisError) {
    logger.error('redis_otp_rate_limiter_error', { message: redisError.message });
    if (!isProduction) {
      logger.warn('redis_otp_rate_limiter_fail_open_dev');
      return next();
    }
    return fail(res, 503, 'Service temporarily unavailable. Please try again.');
  }
};

const jsonRateLimitHandler = (message) => (req, res) =>
  fail(res, 429, message);

const apiRateLimiter = disableApiRateLimit
  ? (req, res, next) => next()
  : rateLimit({
      windowMs: Number(process.env.API_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
      max: Number(process.env.API_RATE_LIMIT_MAX || 300),
      standardHeaders: 'draft-7',
      legacyHeaders: false,
      handler: jsonRateLimitHandler('Too many requests. Try again later.'),
    });

const authIpRateLimiter = rateLimit({
  windowMs: Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
  max: Number(process.env.AUTH_RATE_LIMIT_MAX || 60),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: jsonRateLimitHandler('Too many auth requests. Try again later.'),
});

// IP-BASED RATE LIMITING (High) - Auth routes specific limiter
const authRoutesIpRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per window per IP
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: jsonRateLimitHandler('Too many requests from your IP. Try again later.'),
});

const refreshTokenRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number(process.env.REFRESH_RATE_LIMIT_MAX || 10),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: jsonRateLimitHandler('Too many token refresh attempts. Try again later.'),
});

const adminRateLimiter = rateLimit({
  windowMs: Number(process.env.ADMIN_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
  max: Number(process.env.ADMIN_RATE_LIMIT_MAX || 100),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: jsonRateLimitHandler('Too many admin requests. Try again later.'),
});

const couponValidateRateLimiter = rateLimit({
  windowMs: Number(process.env.COUPON_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
  max: Number(process.env.COUPON_RATE_LIMIT_MAX || 30),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: jsonRateLimitHandler('Too many coupon validation attempts. Try again later.'),
});

module.exports = {
  otpRateLimiter,
  apiRateLimiter,
  authIpRateLimiter,
  authRoutesIpRateLimiter,
  refreshTokenRateLimiter,
  adminRateLimiter,
  couponValidateRateLimiter,
};
