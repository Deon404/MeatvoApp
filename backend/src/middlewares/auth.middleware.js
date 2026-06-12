const jwt = require('jsonwebtoken');
const asyncHandler = require('express-async-handler');
const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');

const isTokenBlacklisted = async (token) => {
  const redisClient = require('../db/redis');
  try {
    const blacklisted = await redisClient.get(`blacklist:${token}`);
    return blacklisted === '1';
  } catch (err) {
    logger.error('auth_blacklist_check_failed', { message: err?.message });
    return true;
  }
};

const protect = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : null;

  logger.debug('auth_token_extract', {
    headerPresent: !!header,
    tokenExtracted: !!token,
    clientIP: req.ip,
  });

  if (!token) {
    const err = new Error('Not authorized');
    err.statusCode = 401;
    throw err;
  }

  let decoded;
  try {
    // FIXED: Use proper JWT verification options matching token generation
    decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
      algorithms: ['HS256']
    });
    
    logger.debug('auth_token_decoded', {
      type: decoded.type,
      exp: decoded.exp,
      clientIP: req.ip,
    });
    
  } catch (error) {
    logger.warn('auth_token_invalid', {
      reason: error.message,
      clientIP: req.ip,
    });
    
    const err = new Error('Not authorized');
    err.statusCode = 401;
    throw err;
  }

  // FIXED: Verify it's an access token
  if (decoded.type !== 'access') {
    logger.warn('auth_wrong_token_type', { tokenType: decoded.type, clientIP: req.ip });
    const err = new Error('Not authorized');
    err.statusCode = 401;
    throw err;
  }

  if (await isTokenBlacklisted(token)) {
    logger.warn('auth_token_revoked', { clientIP: req.ip });
    const err = new Error('Not authorized');
    err.statusCode = 401;
    throw err;
  }

  const userId = Number(decoded?.id);
  if (!userId) {
    logger.warn('auth_invalid_user_id', { clientIP: req.ip });
    const err = new Error('Not authorized');
    err.statusCode = 401;
    throw err;
  }

  const { rows } = await query(
    `SELECT id, phone, name, role, created_at,
            mfa_enabled AS "mfaEnabled",
            mfa_secret AS "mfaSecret"
     FROM users
     WHERE id = $1`,
    [userId]
  );
  const user = rows[0];

  if (!user) {
    logger.warn('auth_user_not_found', { userId, clientIP: req.ip });
    const err = new Error('Not authorized');
    err.statusCode = 401;
    throw err;
  }

  logger.debug('auth_success', { userId: user.id, role: user.role, clientIP: req.ip });

  const { mfaSecret, ...safeReqUser } = user;
  req.user = safeReqUser;
  next();
});

const optionalAuth = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : null;
  if (!token) return next();

  try {
    // FIXED: Use proper JWT verification options
    const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
      algorithms: ['HS256']
    });
    
    // Verify it's an access token
    if (decoded.type !== 'access') return next();

    if (await isTokenBlacklisted(token)) return next();
    
    const userId = Number(decoded?.id);
    if (!userId) return next();

    const { rows } = await query(
      `SELECT id, phone, name, role, created_at,
              mfa_enabled AS "mfaEnabled",
              mfa_secret AS "mfaSecret"
       FROM users
       WHERE id = $1`,
      [userId]
    );
    if (rows[0]) {
      const { mfaSecret, ...safeReqUser } = rows[0];
      req.user = safeReqUser;
    }
  } catch (error) {
    logger.debug('optional_auth_token_invalid', { reason: error.message, clientIP: req.ip });
  }

  return next();
});

module.exports = { protect, optionalAuth };
