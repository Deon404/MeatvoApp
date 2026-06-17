const redis = require('../db/redis');
const { logger } = require('../utils/logger');
const { fail } = require('../utils/response');

// MFA VERIFY RATE LIMITING - Redis-based middleware for MFA verify attempts
const mfaRateLimiter = async (req, res, next) => {
  const phone = req.user?.phone;
  if (!phone || typeof phone !== 'string') return next();

  const key = `rl:mfa:${phone}`;

  try {
    const count = await redis.incr(key);

    if (count === 1) {
      await redis.expire(key, 60);
    }

    if (count > 5) {
      return fail(res, 429, 'Too many MFA verification attempts. Please wait before trying again.');
    }

    return next();
  } catch (redisError) {
    logger.error('redis_mfa_rate_limiter_error', { message: redisError.message });
    return fail(res, 503, 'Service temporarily unavailable. Please try again.');
  }
};

module.exports = { mfaRateLimiter };
