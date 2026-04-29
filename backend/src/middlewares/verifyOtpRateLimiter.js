const redis = require('../db/redis');

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
      return res.status(429).json({
        ok: false,
        success: false,
        error: { message: 'Too many OTP verification attempts. Please wait before trying again.' },
        data: {},
        message: 'Too many OTP verification attempts. Please wait before trying again.'
      });
    }

    next();
  } catch (redisError) {
    // If Redis is down, allow request but log the error
    console.error('Redis error in verifyOtpRateLimiter:', redisError);
    next();
  }
};

module.exports = { verifyOtpRateLimiter };
