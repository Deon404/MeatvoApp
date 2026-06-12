const redis = require('../db/redis');
const rateLimit = require('express-rate-limit');
const { fail } = require('../utils/response');

// Max 10 requests per phone per 10 minutes (development-friendly)
const otpRateLimiter = async (req, res, next) => {
  const phone = req.validated?.body?.phone || req.body?.phone;
  if (!phone || typeof phone !== 'string') return next();

  const key = `rl:otp:${phone}`;
  const count = await redis.incr(key);
  if (count === 1) {
    await redis.expire(key, 10 * 60);
  }

  if (count > 10) {
    return fail(res, 429, 'Too many OTP requests. Try again later.');
  }

  return next();
};

const jsonRateLimitHandler = (message) => (req, res) =>
  fail(res, 429, message);

const apiRateLimiter = rateLimit({
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

module.exports = { otpRateLimiter, apiRateLimiter, authIpRateLimiter, authRoutesIpRateLimiter };
