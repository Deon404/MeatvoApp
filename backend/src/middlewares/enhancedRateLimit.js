// Enhanced rate limiters (Redis-backed when Redis is available).
// NOTE: rate-limit-redis requires a real Redis client with a `sendCommand` method.
// Our redis.js exports a proxy that falls back to in-memory when Redis is down — it
// does NOT expose `.call()`. This file therefore uses the default in-memory store so
// it works reliably in all environments. Swap the `store` line back in when a dedicated
// ioredis client is wired up separately.
//
// All handlers use fail() so every 429 response matches the standard API envelope:
//   { ok, success, error: { message, code }, data, message }

const rateLimit = require('express-rate-limit');
const { fail } = require('../utils/response');

const makeHandler = (message, code) => (req, res) =>
  fail(res, 429, message, { code });

// OTP send — max 3 per phone per 15 minutes
// Phone number is always present on this route (validated upstream); no IP fallback needed.
const otpRateLimit = rateLimit({
  keyGenerator: (req) =>
    `otp:${req.body?.phone || req.validated?.body?.phone || 'unknown'}`,
  windowMs: 15 * 60 * 1000,
  max: 3,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: makeHandler(
    'Too many OTP requests. Please try again after 15 minutes.',
    'OTP_RATE_LIMIT_EXCEEDED'
  ),
});

// OTP verify — max 5 per phone per 5 minutes
const verifyOtpRateLimit = rateLimit({
  keyGenerator: (req) =>
    `verify:${req.body?.phone || req.validated?.body?.phone || 'unknown'}`,
  windowMs: 5 * 60 * 1000,
  max: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: makeHandler(
    'Too many verification attempts. Please try again after 5 minutes.',
    'VERIFY_RATE_LIMIT_EXCEEDED'
  ),
});

// Global API — max 1000 per IP per 15 minutes
const globalRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: makeHandler(
    'Too many requests. Please try again later.',
    'GLOBAL_RATE_LIMIT_EXCEEDED'
  ),
});

// Auth routes — max 50 per IP per 15 minutes (stricter)
const authRoutesRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: makeHandler(
    'Too many authentication attempts. Please try again later.',
    'AUTH_RATE_LIMIT_EXCEEDED'
  ),
});

module.exports = { otpRateLimit, verifyOtpRateLimit, globalRateLimit, authRoutesRateLimit };
