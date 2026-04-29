const express = require('express');
const router = express.Router();

const { sendOtp, verifyOtp, refreshToken, getMe, logout } = require('./auth.controller');
const { otpRateLimiter, authRoutesIpRateLimiter } = require('../../middlewares/rateLimiter');
const { verifyOtpRateLimiter } = require('../../middlewares/verifyOtpRateLimiter');
const { validate } = require('../../middlewares/validate.middleware');
const { authenticateToken } = require('../../middlewares/enhancedAuth.middleware');
const { sendOtpSchema, verifyOtpSchema, refreshTokenSchema } = require('./auth.validation');

// Async middleware wrapper
const asyncMiddleware = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// Public OTP/JWT endpoints with IP-based rate limiting
router.post('/send-otp', authRoutesIpRateLimiter, validate(sendOtpSchema), otpRateLimiter, sendOtp);
router.post('/verify-otp', authRoutesIpRateLimiter, validate(verifyOtpSchema), verifyOtpRateLimiter, verifyOtp);
router.post('/refresh-token', validate(refreshTokenSchema), refreshToken);

// Authenticated user/session endpoints
router.get('/me', asyncMiddleware(authenticateToken), getMe);
router.post('/logout', asyncMiddleware(authenticateToken), logout);

// MFA routes
router.use('/mfa', require('./enhanced-auth.routes'));

module.exports = router;
