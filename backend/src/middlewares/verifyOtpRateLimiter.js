const redis = require('../db/redis');
const { logger } = require('../utils/logger');
const { fail } = require('../utils/response');

// VERIFY-OTP RATE LIMITING (High) - Redis-based middleware for OTP verify attempts
const verifyOtpRateLimiter = async (req, res, next) => {
  const phone = req.validated?.body?.phone || req.body?.phone;
  if (!phone || typeof phone !== 'string') return next();

  const key = `rl:verify:${phone}`;
  
  try {
    const count = await redis.incr(key);
    
    // Set expiry on first request (60 seconds)
    if (count === 1) {
      await redis.expire(key, 60);
    }

    // Check if limit exceeded (5 attempts per 60 seconds)
    if (count > 5) {
      return fail(res, 429, 'Too many OTP verification attempts. Please wait before trying again.');
    }

    return next();
  } catch (err) {
    logger.error('Rate limit Redis error:', err);
    if (String(process.env.NODE_ENV || '').toLowerCase() !== 'production') {
      logger.warn('verify_otp_rate_limiter_fail_open_dev');
      return next();
    }
    next(new Error('Service temporarily unavailable'));
  }
};

module.exports = { verifyOtpRateLimiter };
