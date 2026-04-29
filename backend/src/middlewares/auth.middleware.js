const jwt = require('jsonwebtoken');
const asyncHandler = require('express-async-handler');
const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');

const protect = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : null;

  // DEBUG: Log authorization header and token extraction
  logger.info('AUTH_DEBUG', {
    authorizationHeader: header ? 'Bearer [REDACTED]' : 'MISSING',
    tokenExtracted: !!token,
    clientIP: req.ip,
    userAgent: req.headers['user-agent']
  });

  if (!token) {
    res.status(401);
    throw new Error('Not authorized');
  }

  let decoded;
  try {
    // FIXED: Use proper JWT verification options matching token generation
    decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
      algorithms: ['HS256']
    });
    
    // DEBUG: Log decoded token
    logger.info('AUTH_DEBUG', {
      decodedToken: {
        sub: decoded.sub,
        role: decoded.role,
        type: decoded.type,
        iat: decoded.iat,
        exp: decoded.exp
      },
      clientIP: req.ip
    });
    
  } catch (error) {
    // DEBUG: Log verification error
    logger.warn('AUTH_DEBUG', {
      verificationError: error.message,
      clientIP: req.ip,
      userAgent: req.headers['user-agent']
    });
    
    res.status(401);
    throw new Error('Not authorized');
  }

  // FIXED: Verify it's an access token
  if (decoded.type !== 'access') {
    logger.warn('AUTH_DEBUG', {
      tokenType: decoded.type,
      expectedType: 'access',
      clientIP: req.ip
    });
    
    res.status(401);
    throw new Error('Not authorized');
  }

  const userId = Number(decoded?.id);
  if (!userId) {
    logger.warn('AUTH_DEBUG', {
      userId: decoded?.id,
      clientIP: req.ip
    });
    
    res.status(401);
    throw new Error('Not authorized');
  }

  const { rows } = await query(
    'SELECT id, phone, name, role, created_at FROM users WHERE id = $1',
    [userId]
  );
  const user = rows[0];

  if (!user) {
    logger.warn('AUTH_DEBUG', {
      userId,
      userFound: false,
      clientIP: req.ip
    });
    
    res.status(401);
    throw new Error('Not authorized');
  }

  // DEBUG: Log successful authentication
  logger.info('AUTH_DEBUG', {
    authenticated: true,
    user: {
      id: user.id,
      role: user.role,
      phone: user.phone ? '******' + user.phone.slice(-4) : null
    },
    clientIP: req.ip
  });
  
  req.user = user;
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
    
    const userId = Number(decoded?.id);
    if (!userId) return next();

    const { rows } = await query(
      'SELECT id, phone, name, role, created_at FROM users WHERE id = $1',
      [userId]
    );
    if (rows[0]) req.user = rows[0];
  } catch (error) {
    // Ignore invalid tokens for public endpoints.
    logger.warn('AUTH_DEBUG', {
      optionalAuthError: error.message,
      clientIP: req.ip
    });
  }

  return next();
});

module.exports = { protect, optionalAuth };
