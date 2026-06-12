const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');
const { fail } = require('../utils/response');

const {
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
  getSecurityStats,
} = require('./services');

const {
  csrfProtection,
  cspProtection,
  deviceTracking,
  sessionTracking,
  securityHeaders,
  xssProtection,
  apiAbusePrevention,
  helmet,
  cookieParser,
} = require('./security.middleware');

const initializeSecurity = (app) => {
  try {
    logger.info('initializing_security_services');

    setupSecurityMonitoring();
    setupPeriodicCleanup();

    if (app) {
      app.use(cookieParser());
      app.use(checkSuspiciousActivity);
      app.use(securityAudit);
      app.use(xssProtection);
      app.use(apiAbusePrevention);
      logger.info('security_middleware_wired');
    }

    logger.info('security_services_initialized');
  } catch (error) {
    logger.error('security_initialization_failed', { error: error.message });
    sentry.captureException(error);
  }
};

const setupSecurityMonitoring = () => {
  try {
    redisSecurity.monitorSecurityEvents();

    process.on('uncaughtException', (error) => {
      logger.error('uncaught_exception_security', { error: error.message });
      sentry.captureException(error);
    });

    process.on('unhandledRejection', (reason) => {
      logger.error('unhandled_rejection_security', { reason });
      sentry.captureException(new Error(reason));
    });

    logger.info('security_monitoring_setup_complete');
  } catch (error) {
    logger.error('security_monitoring_setup_failed', { error: error.message });
  }
};

const setupPeriodicCleanup = () => {
  try {
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
    }, 5 * 60 * 1000);

    logger.info('periodic_cleanup_setup_complete');
  } catch (error) {
    logger.error('periodic_cleanup_setup_failed', { error: error.message });
  }
};

const checkSuspiciousActivity = (req, res, next) => {
  try {
    const suspiciousPatterns = [
      /\.\.\//,
      /<script/i,
      /union.*select/i,
      /javascript:/i,
      /data:.*base64/i,
    ];

    const requestString = JSON.stringify({
      path: req.path,
      query: req.query,
      body: req.body,
      headers: req.headers,
    });

    const isSuspicious = suspiciousPatterns.some((pattern) => pattern.test(requestString));

    if (isSuspicious) {
      logger.warn('suspicious_request_detected', {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        path: req.path,
        method: req.method,
      });

      sentry.addBreadcrumb({
        message: 'Suspicious request detected',
        category: 'security',
        level: 'warning',
        data: {
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          path: req.path,
          method: req.method,
        },
      });

      if (process.env.NODE_ENV === 'production') {
        return fail(res, 403, 'Request blocked due to suspicious activity', { code: 'SUSPICIOUS_ACTIVITY' });
      }
    }

    next();
  } catch (error) {
    logger.error('suspicious_activity_check_error', { error: error.message });
    next();
  }
};

const createRateLimiter = (options = {}) => {
  const {
    windowMs = 15 * 60 * 1000,
    max = 100,
    message = 'Too many requests, please try again later.',
    keyGenerator = (req) => req.ip,
  } = options;

  const requests = new Map();

  return (req, res, next) => {
    try {
      const key = keyGenerator(req);
      const now = Date.now();
      const windowStart = now - windowMs;

      let requestData = requests.get(key) || {
        requests: [],
        resetTime: now + windowMs,
      };

      requestData.requests = requestData.requests.filter((timestamp) => timestamp > windowStart);

      if (requestData.requests.length >= max) {
        logger.warn('rate_limit_exceeded', {
          key,
          requests: requestData.requests.length,
          max,
          ip: req.ip,
        });

        return fail(res, 429, message, {
          code: 'RATE_LIMITED',
          retryAfter: Math.ceil((requestData.resetTime - now) / 1000),
        });
      }

      requestData.requests.push(now);
      requests.set(key, requestData);

      res.set({
        'X-RateLimit-Limit': max,
        'X-RateLimit-Remaining': Math.max(0, max - requestData.requests.length),
        'X-RateLimit-Reset': Math.ceil(requestData.resetTime / 1000),
      });

      next();
    } catch (error) {
      logger.error('rate_limiting_error', { error: error.message });
      next();
    }
  };
};

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
      requestId: req.requestId,
    };

    const securityRelevantPaths = ['/api/auth', '/api/payments', '/api/admin', '/api/users'];
    const isSecurityRelevant = securityRelevantPaths.some((path) => req.path.startsWith(path));

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

  initializeSecurity,
  getSecurityStats,
};
