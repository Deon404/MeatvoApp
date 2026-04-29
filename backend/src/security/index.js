const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

// Import all security services
const csrfService = require('./csrf.service');
const cspService = require('./csp.service');
const deviceService = require('./device.service');
const sessionService = require('./session.service');
const paymentSecurity = require('./payment.security');
const fileSecurity = require('./file.security');
const redisSecurity = require('./redis.security');
const socketSecurity = require('./socket.security');
const jwtSecurity = require('./jwt.security');
const otpSecurity = require('./otp.security');
const accountLockoutService = require('./account-lockout.service');
const apiAbuseService = require('./api-abuse.service');
const securityRoutes = require('./security-routes');

// Import security middleware
const {
  csrfProtection,
  cspProtection,
  deviceTracking,
  sessionTracking,
  securityHeaders,
  xssProtection,
  apiAbusePrevention,
  helmet,
  cookieParser
} = require('./security.middleware');

/**
 * Initialize all security services
 */
const initializeSecurity = () => {
  try {
    logger.info('initializing_security_services');

    // Initialize security monitoring
    setupSecurityMonitoring();

    // Set up periodic cleanup
    setupPeriodicCleanup();

    logger.info('security_services_initialized');
  } catch (error) {
    logger.error('security_initialization_failed', { error: error.message });
    sentry.captureException(error);
  }
};

/**
 * Set up security monitoring
 */
const setupSecurityMonitoring = () => {
  try {
    // Monitor Redis security
    redisSecurity.monitorSecurityEvents();

    // Set up security event listeners
    process.on('uncaughtException', (error) => {
      logger.error('uncaught_exception_security', { error: error.message });
      sentry.captureException(error);
    });

    process.on('unhandledRejection', (reason, promise) => {
      logger.error('unhandled_rejection_security', { reason });
      sentry.captureException(new Error(reason));
    });

    logger.info('security_monitoring_setup_complete');
  } catch (error) {
    logger.error('security_monitoring_setup_failed', { error: error.message });
  }
};

/**
 * Set up periodic cleanup tasks
 */
const setupPeriodicCleanup = () => {
  try {
    // Clean up expired data every 5 minutes
    setInterval(() => {
      try {
        csrfService.cleanupExpiredTokens();
        cspService.cleanupExpiredNonces();
        deviceService.cleanupExpiredDevices();
        sessionService.cleanupExpiredSessions();
        jwtSecurity.cleanupExpiredTokens();
        otpSecurity.cleanupExpiredOTPs();
        paymentSecurity.cleanupPaymentAttempts();
        fileSecurity.cleanupExpiredFiles?.();
      } catch (error) {
        logger.error('periodic_cleanup_error', { error: error.message });
      }
    }, 5 * 60 * 1000); // 5 minutes

    logger.info('periodic_cleanup_setup_complete');
  } catch (error) {
    logger.error('periodic_cleanup_setup_failed', { error: error.message });
  }
};

/**
 * Get comprehensive security statistics
 */
const getSecurityStats = () => {
  try {
    return {
      csrf: {
        activeTokens: csrfService.tokens.size
      },
      csp: {
        activeNonces: cspService.nonces.size
      },
      devices: {
        totalDevices: deviceService.devices.size
      },
      sessions: {
        ...sessionService.getSessionStats()
      },
      payments: {
        ...paymentSecurity.getPaymentSecurityStats()
      },
      files: {
        ...fileSecurity.getFileSecurityStats()
      },
      redis: {
        ...redisSecurity.getSecurityStats()
      },
      sockets: {
        ...socketSecurity.getSecurityStats()
      },
      jwt: {
        ...jwtSecurity.getSecurityStats()
      },
      otp: {
        ...otpSecurity.getSecurityStats()
      }
    };
  } catch (error) {
    logger.error('security_stats_error', { error: error.message });
    return {};
  }
};

/**
 * Enhanced security check for suspicious activity
 */
const checkSuspiciousActivity = (req, res, next) => {
  try {
    const suspiciousPatterns = [
      /\.\.\//,  // Path traversal
      /<script/i,  // Script injection
      /union.*select/i,  // SQL injection
      /javascript:/i,  // JavaScript protocol
      /data:.*base64/i  // Base64 data URLs
    ];

    const requestString = JSON.stringify({
      path: req.path,
      query: req.query,
      body: req.body,
      headers: req.headers
    });

    const isSuspicious = suspiciousPatterns.some(pattern => pattern.test(requestString));

    if (isSuspicious) {
      logger.warn('suspicious_request_detected', {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        path: req.path,
        method: req.method
      });

      sentry.addBreadcrumb({
        message: 'Suspicious request detected',
        category: 'security',
        level: 'warning',
        data: {
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          path: req.path,
          method: req.method
        }
      });

      // Block suspicious requests in production
      if (process.env.NODE_ENV === 'production') {
        return res.status(403).json({
          success: false,
          message: 'Request blocked due to suspicious activity'
        });
      }
    }

    next();
  } catch (error) {
    logger.error('suspicious_activity_check_error', { error: error.message });
    next(); // Don't block on error
  }
};

/**
 * Rate limiting middleware with Redis support
 */
const createRateLimiter = (options = {}) => {
  const {
    windowMs = 15 * 60 * 1000, // 15 minutes
    max = 100, // Max requests per window
    message = 'Too many requests, please try again later.',
    keyGenerator = (req) => req.ip,
    skipSuccessfulRequests = false,
    skipFailedRequests = false
  } = options;

  const requests = new Map(); // In production, use Redis

  return (req, res, next) => {
    try {
      const key = keyGenerator(req);
      const now = Date.now();
      const windowStart = now - windowMs;

      // Get existing request data
      let requestData = requests.get(key) || {
        requests: [],
        resetTime: now + windowMs
      };

      // Clean up old requests
      requestData.requests = requestData.requests.filter(timestamp => timestamp > windowStart);

      // Check if limit exceeded
      if (requestData.requests.length >= max) {
        logger.warn('rate_limit_exceeded', {
          key,
          requests: requestData.requests.length,
          max,
          ip: req.ip
        });

        return res.status(429).json({
          success: false,
          message,
          retryAfter: Math.ceil((requestData.resetTime - now) / 1000)
        });
      }

      // Add current request
      requestData.requests.push(now);
      requests.set(key, requestData);

      // Add rate limit headers
      res.set({
        'X-RateLimit-Limit': max,
        'X-RateLimit-Remaining': Math.max(0, max - requestData.requests.length),
        'X-RateLimit-Reset': Math.ceil(requestData.resetTime / 1000)
      });

      next();
    } catch (error) {
      logger.error('rate_limiting_error', { error: error.message });
      next(); // Don't block on error
    }
  };
};

/**
 * Security audit middleware
 */
const securityAudit = (req, res, next) => {
  try {
    const auditData = {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      method: req.method,
      path: req.path,
      userAgent: req.get('User-Agent'),
      userId: req.user?.id,
      sessionId: req.session?.id,
      requestId: req.requestId
    };

    // Log security-relevant requests
    const securityRelevantPaths = [
      '/api/auth',
      '/api/payments',
      '/api/admin',
      '/api/users'
    ];

    const isSecurityRelevant = securityRelevantPaths.some(path => req.path.startsWith(path));

    if (isSecurityRelevant) {
      logger.info('security_audit', auditData);
    }

    next();
  } catch (error) {
    logger.error('security_audit_error', { error: error.message });
    next();
  }
};

module.exports = {
  // Services
  csrfService,
  cspService,
  deviceService,
  sessionService,
  paymentSecurity,
  fileSecurity,
  redisSecurity,
  socketSecurity,
  jwtSecurity,
  otpSecurity,
  accountLockoutService,
  apiAbuseService,

  // Middleware
  csrfProtection,
  cspProtection,
  deviceTracking,
  sessionTracking,
  securityHeaders,
  xssProtection,
  apiAbusePrevention,
  helmet,
  cookieParser,
  checkSuspiciousActivity,
  createRateLimiter,
  securityAudit,
  securityRoutes,

  // Utilities
  initializeSecurity,
  getSecurityStats
};
