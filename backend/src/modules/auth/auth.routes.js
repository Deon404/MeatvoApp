const express = require('express');
const router = express.Router();

const { sendOtp, verifyOtp, refreshToken, getMe, logout } = require('./auth.controller');
const { query } = require('../../db/postgres');
const { otpRateLimiter, authRoutesIpRateLimiter, refreshTokenRateLimiter } = require('../../middlewares/rateLimiter');
const { verifyOtpRateLimiter } = require('../../middlewares/verifyOtpRateLimiter');
const { validate } = require('../../middlewares/validate.middleware');
const { authenticateToken } = require('../../middlewares/enhancedAuth.middleware');
const { sendOtpSchema, verifyOtpSchema, refreshTokenSchema } = require('./auth.validation');

// Async middleware wrapper
const asyncMiddleware = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// Public OTP/JWT endpoints with IP-based rate limiting
router.post('/send-otp', authRoutesIpRateLimiter, validate(sendOtpSchema), otpRateLimiter, sendOtp);
router.post('/verify-otp', authRoutesIpRateLimiter, validate(verifyOtpSchema), verifyOtpRateLimiter, verifyOtp);
router.post('/refresh-token', refreshTokenRateLimiter, validate(refreshTokenSchema), refreshToken);
router.post('/refresh', refreshTokenRateLimiter, validate(refreshTokenSchema), refreshToken);
router.get('/health', async (req, res) => {
  try {
    await query('SELECT 1');
    return res.status(200).json({ status: 'OK', db: 'connected' });
  } catch (_error) {
    return res.status(503).json({ status: 'ERROR', db: 'disconnected' });
  }
});

// Authenticated user/session endpoints
router.get('/me', asyncMiddleware(authenticateToken), getMe);
router.post('/logout', asyncMiddleware(authenticateToken), logout);

// MFA routes
router.use('/mfa', require('./enhanced-auth.routes'));

module.exports = router;
