const jwt = require('jsonwebtoken');
const speakeasy = require('speakeasy');
const mfaService = require('../modules/auth/mfa.service');
const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');
const { fail } = require('../utils/response');

class EnhancedAuthMiddleware {
  constructor() {
    this.loginAttempts = new Map(); // In production, use Redis
    this.lockoutDuration = 15 * 60 * 1000; // 15 minutes
    this.maxAttempts = 5;
  }

  // Enhanced rate limiting for authentication
  authRateLimiter(req, res, next) {
    const key = this.getClientKey(req);
    const attempts = this.loginAttempts.get(key) || { count: 0, lastAttempt: 0 };
    const now = Date.now();

    // Reset attempts if lockout period has passed
    if (attempts.lockUntil && now < attempts.lockUntil) {
      const remainingTime = Math.ceil((attempts.lockUntil - now) / 1000);
      
      logger.warn('auth_rate_limit_blocked', {
        key,
        remainingTime,
        ip: req.ip
      });

      return fail(res, 429, `Too many failed attempts. Try again in ${remainingTime} seconds.`, {
        code: 'RATE_LIMITED',
        retryAfter: remainingTime,
      });
    }

    // Reset count if last attempt was more than 15 minutes ago
    if (now - attempts.lastAttempt > this.lockoutDuration) {
      attempts.count = 0;
    }

    next();
  }

  // Record failed login attempt
  recordFailedAttempt(req) {
    const key = this.getClientKey(req);
    const attempts = this.loginAttempts.get(key) || { count: 0, lastAttempt: 0 };
    const now = Date.now();

    attempts.count++;
    attempts.lastAttempt = now;

    // Lock account if max attempts reached
    if (attempts.count >= this.maxAttempts) {
      attempts.lockUntil = now + this.lockoutDuration;
      
      logger.warn('auth_account_locked', {
        key,
        attempts: attempts.count,
        lockedUntil: new Date(attempts.lockUntil).toISOString(),
        ip: req.ip
      });

      sentry.addBreadcrumb({
        message: 'Account locked due to too many failed attempts',
        category: 'auth',
        level: 'warning',
        data: { key, attempts: attempts.count, ip: req.ip }
      });
    }

    this.loginAttempts.set(key, attempts);
  }

  // Clear failed attempts on successful login
  clearFailedAttempts(req) {
    const key = this.getClientKey(req);
    this.loginAttempts.delete(key);
    
    logger.info('auth_attempts_cleared', { key, ip: req.ip });
  }

  // Get client key for rate limiting
  getClientKey(req) {
    // Use combination of IP and User-Agent for better identification
    const ip = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent') || 'unknown';
    const hash = require('crypto')
      .createHash('sha256')
      .update(`${ip}:${userAgent}`)
      .digest('hex')
      .substring(0, 16);
    
    return `auth:${hash}`;
  }

  // Enhanced JWT authentication with MFA support
  async authenticateToken(req, res, next) {
    try {
      const authHeader = req.headers.authorization;
      
      if (!authHeader) {
        return fail(res, 401, 'Access token is required', { code: 'TOKEN_MISSING' });
      }

      const token = authHeader.startsWith('Bearer ') 
        ? authHeader.substring(7) 
        : authHeader;

      if (!token) {
        return fail(res, 401, 'Invalid token format', { code: 'TOKEN_MISSING' });
      }

      // Verify JWT token
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
        issuer: 'meatvo-app',
        audience: 'meatvo-users',
        algorithms: ['HS256']
      });
      
      // Check if token is blacklisted
      if (await this.isTokenBlacklisted(token)) {
        return fail(res, 401, 'Token has been revoked', { code: 'TOKEN_REVOKED' });
      }

      const userId = Number(decoded.id || decoded.sub);
      const { rows } = await query(
        `SELECT id, phone, name, role,
                mfa_enabled AS "mfaEnabled",
                mfa_secret AS "mfaSecret"
         FROM users
         WHERE id = $1`,
        [userId]
      );

      if (!rows[0]) {
        return fail(res, 401, 'User not found', { code: 'USER_NOT_FOUND' });
      }

      // Add user to request object
      req.user = rows[0];
      req.token = token;

      // Add authentication breadcrumb
      if (sentry && sentry.addBreadcrumb) {
        sentry.addBreadcrumb({
          message: 'JWT token verified',
          category: 'auth',
          level: 'info',
          data: { userId: rows[0].id, role: rows[0].role }
        });
      }

      next();
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        return fail(res, 401, 'Token has expired', { code: 'TOKEN_EXPIRED' });
      } else if (error.name === 'JsonWebTokenError') {
        return fail(res, 401, 'Invalid token', { code: 'TOKEN_INVALID' });
      } else {
        logger.error('jwt_verification_error', { error: error.message });
        sentry.captureException(error);
        return fail(res, 500, 'Authentication error', { code: 'AUTH_ERROR' });
      }
    }
  }

  // MFA verification middleware
  requireMFA(req, res, next) {
    if (!req.user) {
      return fail(res, 401, 'Authentication required', { code: 'AUTH_REQUIRED' });
    }

    // Check if MFA is enabled for the user
    if (mfaService.isMFAEnabled(req.user)) {
      const mfaToken = req.headers['x-mfa-token'];
      
      if (!mfaToken) {
        return fail(res, 401, 'MFA token is required', { code: 'MFA_REQUIRED' });
      }

      // Verify MFA token
      const isValid = mfaService.verifyToken(mfaToken, req.user.mfaSecret);
      
      if (!isValid) {
        logger.warn('mfa_verification_failed', {
          userId: req.user.id,
          ip: req.ip
        });

        sentry.addBreadcrumb({
          message: 'MFA verification failed',
          category: 'auth',
          level: 'warning',
          data: { userId: req.user.id, ip: req.ip }
        });

        return fail(res, 401, 'Invalid MFA token', { code: 'MFA_INVALID' });
      }
    }

    next();
  }

  // Role-based access control with MFA requirements
  requireRole(roles, requireMFA = false) {
    return (req, res, next) => {
      if (!req.user) {
        return fail(res, 401, 'Authentication required', { code: 'AUTH_REQUIRED' });
      }

      const userRole = req.user.role;
      const hasRole = Array.isArray(roles) 
        ? roles.includes(userRole)
        : roles === userRole;

      if (!hasRole) {
        logger.warn('unauthorized_access_attempt', {
          userId: req.user.id,
          userRole,
          requiredRoles: roles,
          ip: req.ip,
          url: req.url
        });

        sentry.addBreadcrumb({
          message: 'Unauthorized access attempt',
          category: 'auth',
          level: 'warning',
          data: { 
            userId: req.user.id, 
            userRole, 
            requiredRoles: roles,
            ip: req.ip,
            url: req.url
          }
        });

        return fail(res, 403, 'Insufficient permissions', { code: 'INSUFFICIENT_PERMISSIONS' });
      }

      // Check MFA requirement for sensitive operations
      if (requireMFA && mfaService.isMFAEnabled(req.user)) {
        const mfaToken = req.headers['x-mfa-token'];
        
        if (!mfaToken) {
          return fail(res, 401, 'MFA token is required for this operation', { code: 'MFA_REQUIRED' });
        }

        const isValid = mfaService.verifyToken(mfaToken, req.user.mfaSecret);
        
        if (!isValid) {
          return fail(res, 401, 'Invalid MFA token', { code: 'MFA_INVALID' });
        }
      }

      next();
    };
  }

  // Check if token is blacklisted
  async isTokenBlacklisted(token) {
    const redisClient = require('../db/redis');
    try {
      const blacklisted = await redisClient.get(`blacklist:${token}`);
      return blacklisted === '1';
    } catch (err) {
      logger.error('Redis blacklist check failed:', err);
      return true; // fail-closed: treat as blacklisted if Redis down
    }
  }

  // Blacklist a token (for logout)
  async blacklistToken(token) {
    const redisClient = require('../db/redis');
    const decoded = jwt.decode(token);
    if (decoded && decoded.exp) {
      const ttl = Math.max(1, Math.floor(decoded.exp - Date.now() / 1000));
      await redisClient.set(`blacklist:${token}`, '1', 'EX', ttl);
      logger.info('token_blacklisted', { token: token.substring(0, 10) + '...' });
    }
  }

  // Session management middleware
  sessionManager(req, res, next) {
    const sessionId = req.headers['x-session-id'];
    const userId = req.user?.id;

    if (sessionId && userId) {
      // In production, use Redis to manage sessions
      // Store session activity
      this.updateSessionActivity(sessionId, userId);
    }

    next();
  }

  // Update session activity
  updateSessionActivity(sessionId, userId) {
    // In production, update in Redis
    // redis.hset(`session:${sessionId}`, 'lastActivity', Date.now());
    // redis.hset(`session:${sessionId}`, 'userId', userId);
    // redis.expire(`session:${sessionId}`, 24 * 60 * 60); // 24 hours
  }

  // Device verification middleware
  requireDeviceVerification(req, res, next) {
    const deviceFingerprint = req.headers['x-device-fingerprint'];
    const user = req.user;

    if (!user) {
      return fail(res, 401, 'Authentication required', { code: 'AUTH_REQUIRED' });
    }

    // In production, check against stored device fingerprints
    // For now, allow all devices
    req.deviceVerified = true;
    next();
  }

  // API rate limiting based on user tier
  apiRateLimiter(tiers = {}) {
    return (req, res, next) => {
      const user = req.user;
      
      if (!user) {
        return next();
      }

      const userTier = user.tier || 'basic';
      const limits = tiers[userTier] || tiers.basic || { requests: 100, window: 15 * 60 * 1000 };
      
      const key = `api:${user.id}:${userTier}`;
      const now = Date.now();
      const window = limits.window;
      
      // In production, use Redis for distributed rate limiting
      const requests = this.getApiRequests(key, now, window);
      
      if (requests >= limits.requests) {
        return fail(res, 429, 'API rate limit exceeded', {
          code: 'RATE_LIMITED',
          retryAfter: Math.ceil(window / 1000),
          limit: limits.requests,
          remaining: 0,
        });
      }

      this.recordApiRequest(key, now);
      
      // Add rate limit headers
      res.set({
        'X-RateLimit-Limit': limits.requests,
        'X-RateLimit-Remaining': Math.max(0, limits.requests - requests - 1),
        'X-RateLimit-Reset': new Date(now + window).toISOString()
      });

      next();
    };
  }

  // Get API requests for rate limiting
  getApiRequests(key, now, window) {
    // In production, use Redis
    // For now, use in-memory storage
    const requests = this.apiRequests?.get(key) || [];
    const validRequests = requests.filter(timestamp => now - timestamp < window);
    return validRequests.length;
  }

  // Record API request
  recordApiRequest(key, timestamp) {
    // In production, use Redis
    // For now, use in-memory storage
    if (!this.apiRequests) {
      this.apiRequests = new Map();
    }
    
    const requests = this.apiRequests.get(key) || [];
    requests.push(timestamp);
    
    // Keep only requests within the window
    const now = Date.now();
    const validRequests = requests.filter(reqTime => now - reqTime < 15 * 60 * 1000);
    this.apiRequests.set(key, validRequests);
  }

  // Security headers middleware
  securityHeaders(req, res, next) {
    // Set security headers
    res.set({
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Referrer-Policy': 'strict-origin-when-cross-origin',
      'Permissions-Policy': 'geolocation=(), microphone=(), camera=(), payment=(), usb=()',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload'
    });

    next();
  }
}

// Create singleton instance
const enhancedAuth = new EnhancedAuthMiddleware();

// Admin only middleware shortcut
const adminOnly = enhancedAuth.requireRole('admin');

module.exports = {
  authenticateToken: enhancedAuth.authenticateToken.bind(enhancedAuth),
  requireRole: enhancedAuth.requireRole.bind(enhancedAuth),
  requireMFA: enhancedAuth.requireMFA.bind(enhancedAuth),
  authRateLimiter: enhancedAuth.authRateLimiter.bind(enhancedAuth),
  sessionManager: enhancedAuth.sessionManager.bind(enhancedAuth),
  requireDeviceVerification: enhancedAuth.requireDeviceVerification.bind(enhancedAuth),
  apiRateLimiter: enhancedAuth.apiRateLimiter.bind(enhancedAuth),
  securityHeaders: enhancedAuth.securityHeaders.bind(enhancedAuth),
  recordFailedAttempt: enhancedAuth.recordFailedAttempt.bind(enhancedAuth),
  clearFailedAttempts: enhancedAuth.clearFailedAttempts.bind(enhancedAuth),
  blacklistToken: enhancedAuth.blacklistToken.bind(enhancedAuth),
  adminOnly // Export shortcut for admin routes
};
