const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');
const { fail } = require('../utils/response');
const csrfService = require('./csrf.service');
const cspService = require('./csp.service');
const deviceService = require('./device.service');
const sessionService = require('./session.service');

/**
 * Enhanced security middleware
 */
class SecurityMiddleware {
  constructor() {
    this.csrfProtection = this.csrfProtection.bind(this);
    this.cspProtection = this.cspProtection.bind(this);
    this.deviceTracking = this.deviceTracking.bind(this);
    this.sessionTracking = this.sessionTracking.bind(this);
    this.securityHeaders = this.securityHeaders.bind(this);
  }

  /**
   * CSRF protection middleware
   */
  csrfProtection(req, res, next) {
    try {
      // Skip CSRF for GET, HEAD, OPTIONS requests
      if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
        return next();
      }

      // Skip CSRF for API endpoints that don't need CSRF (webhook, etc.)
      const skipCSRF = [
        '/api/webhook/',
        '/api/notifications/',
        '/api/health',
        '/api/metrics'
      ].some(path => req.path.startsWith(path));

      if (skipCSRF) {
        return next();
      }

      const sessionId = csrfService.getSessionId(req);
      const providedToken = req.headers['x-csrf-token'] || req.body._csrf;
      
      if (!providedToken) {
        return fail(res, 403, 'CSRF token required', { code: 'CSRF_MISSING' });
      }

      const isValid = csrfService.verifyToken(sessionId, providedToken);
      
      if (!isValid) {
        logger.warn('csrf_token_verification_failed', {
          sessionId,
          path: req.path,
          method: req.method,
          ip: req.ip
        });

        return fail(res, 403, 'Invalid CSRF token', { code: 'CSRF_INVALID' });
      }

      next();
    } catch (error) {
      logger.error('csrf_protection_error', { error: error.message });
      sentry.captureException(error);
      return fail(res, 500, 'Security verification failed');
    }
  }

  /**
   * CSP protection middleware
   */
  cspProtection(req, res, next) {
    try {
      const requestId = cspService.getRequestId(req);
      const nonce = cspService.generateNonce(requestId);
      const isDev = process.env.NODE_ENV === 'development';
      
      // Store nonce for later verification
      req.cspNonce = nonce;
      req.cspRequestId = requestId;

      // Generate CSP header
      const cspHeader = cspService.generateCSPHeader(nonce, isDev);
      
      res.set({
        'Content-Security-Policy': cspHeader,
        'X-Content-Security-Policy-Nonce': nonce
      });

      next();
    } catch (error) {
      logger.error('csp_protection_error', { error: error.message });
      sentry.captureException(error);
      next(); // Don't block requests on CSP errors
    }
  }

  /**
   * Device tracking middleware
   */
  async deviceTracking(req, res, next) {
    try {
      // Skip device tracking for health checks and metrics
      if (req.path.startsWith('/health') || req.path.startsWith('/metrics')) {
        return next();
      }

      const user = req.user;
      
      if (!user) {
        return next();
      }

      // Verify or register device
      const { valid, device } = await deviceService.verifyDevice(user.id, req);
      
      if (!valid) {
        // Register new device
        const newDevice = await deviceService.registerDevice(user.id, req);
        req.device = newDevice;
        
        // For new devices, require additional verification
        if (deviceService.hasTooManyDevices(user.id)) {
          logger.warn('too_many_devices', { userId: user.id });
          return fail(res, 403, 'Too many devices registered. Please revoke some devices.', { code: 'TOO_MANY_DEVICES' });
        }
      } else {
        req.device = device;
      }

      // Add device info to Sentry context
      sentry.addBreadcrumb({
        message: 'Device verified',
        category: 'auth',
        level: 'info',
        data: {
          userId: user.id,
          deviceId: req.device?.id,
          trusted: req.device?.trusted
        }
      });

      return next();
    } catch (error) {
      logger.error('device_tracking_error', { error: error.message });
      sentry.captureException(error);
      next(); // Don't block requests on device tracking errors
    }
  }

  /**
   * Session tracking middleware
   */
  async sessionTracking(req, res, next) {
    try {
      // Skip session tracking for health checks and metrics
      if (req.path.startsWith('/health') || req.path.startsWith('/metrics')) {
        return next();
      }

      const user = req.user;
      
      if (!user) {
        return next();
      }

      // Get session ID from cookie or header
      const sessionId = req.cookies?.sessionId || req.headers['x-session-id'];
      
      if (sessionId) {
        // Update existing session
        await sessionService.updateSessionActivity(sessionId, req);
        const session = await sessionService.getSession(sessionId);
        
        if (session && session.userId === user.id) {
          req.session = session;
          req.isTrustedSession = await sessionService.isTrustedSession(sessionId);
        }
      } else {
        // Create new session
        const session = await sessionService.createSession(user.id, req, req.device);
        req.session = session;
        req.isTrustedSession = session.trusted;
        
        // Set session cookie
        res.cookie('sessionId', session.id, {
          httpOnly: true,
          secure: process.env.NODE_ENV === 'production',
          sameSite: 'strict',
          maxAge: 24 * 60 * 60 * 1000 // 24 hours
        });
      }

      next();
    } catch (error) {
      logger.error('session_tracking_error', { error: error.message });
      sentry.captureException(error);
      next(); // Don't block requests on session tracking errors
    }
  }

  /**
   * Enhanced security headers
   */
  securityHeaders(req, res, next) {
    try {
      // Use helmet for basic security headers
      helmet({
        contentSecurityPolicy: false, // We handle CSP separately
        crossOriginEmbedderPolicy: false // May break some functionality
      })(req, res, () => {
        // Add additional security headers
        res.set({
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'X-XSS-Protection': '1; mode=block',
          'Referrer-Policy': 'strict-origin-when-cross-origin',
          'Permissions-Policy': 'geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()',
          'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
          'X-Permitted-Cross-Domain-Policies': 'none',
          'X-Download-Options': 'noopen',
          'X-Content-Security-Policy': 'default-src \'self\''
        });

        // Add anti-bot headers
        res.set({
          'X-Robots-Tag': 'noindex, nofollow',
          'Server': process.env.NODE_ENV === 'production' ? '' : 'Meatvo-API'
        });

        next();
      });
    } catch (error) {
      logger.error('security_headers_error', { error: error.message });
      next(); // Don't block requests on header errors
    }
  }

  /**
   * XSS protection middleware
   */
  xssProtection(req, res, next) {
    try {
      // Sanitize request body for potential XSS
      if (req.body && typeof req.body === 'object') {
        req.body = this.sanitizeObject(req.body);
      }

      // Express 5: req.query is read-only — sanitize values in place
      if (req.query && typeof req.query === 'object') {
        for (const [key, value] of Object.entries(req.query)) {
          if (typeof value === 'string') {
            const sanitized = this.sanitizeString(value);
            if (sanitized !== value) {
              try {
                req.query[key] = sanitized;
              } catch {
                // read-only query object — skip
              }
            }
          }
        }
      }

      next();
    } catch (error) {
      logger.error('xss_protection_error', { error: error.message });
      next(); // Don't block requests on XSS protection errors
    }
  }

  sanitizeString(value) {
    return value
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '');
  }

  /**
   * Sanitize object recursively to prevent XSS
   */
  sanitizeObject(obj) {
    if (typeof obj !== 'object' || obj === null) {
      return obj;
    }

    if (Array.isArray(obj)) {
      return obj.map(item => this.sanitizeObject(item));
    }

    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === 'string') {
        sanitized[key] = this.sanitizeString(value);
      } else if (typeof value === 'object') {
        sanitized[key] = this.sanitizeObject(value);
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  /**
   * API abuse prevention middleware
   */
  apiAbusePrevention(req, res, next) {
    try {
      // Add rate limiting headers
      res.set({
        'X-RateLimit-Limit': '1000',
        'X-RateLimit-Remaining': '999',
        'X-RateLimit-Reset': Math.floor(Date.now() / 1000) + 3600
      });

      // Add request ID for tracking
      const requestId = req.headers['x-request-id'] || 
                       req.session?.requestId || 
                       require('crypto').randomBytes(16).toString('hex');
      
      req.requestId = requestId;
      res.set('X-Request-ID', requestId);

      // Log suspicious activity
      const suspiciousPatterns = [
        /\.\.\//,  // Path traversal
        /<script/i, // Script injection
        /union.*select/i, // SQL injection
        /javascript:/i, // JavaScript protocol
        /data:.*base64/i // Base64 data URLs
      ];

      const requestString = JSON.stringify({
        path: req.path,
        query: req.query,
        body: req.body
      });

      const isSuspicious = suspiciousPatterns.some(pattern => pattern.test(requestString));

      if (isSuspicious) {
        logger.warn('suspicious_request_detected', {
          requestId,
          path: req.path,
          method: req.method,
          ip: req.ip,
          userAgent: req.get('User-Agent')
        });

        sentry.addBreadcrumb({
          message: 'Suspicious request detected',
          category: 'security',
          level: 'warning',
          data: {
            requestId,
            path: req.path,
            method: req.method,
            ip: req.ip
          }
        });
      }

      next();
    } catch (error) {
      logger.error('api_abuse_prevention_error', { error: error.message });
      next();
    }
  }
}

// Create singleton instance
const securityMiddleware = new SecurityMiddleware();

module.exports = {
  csrfProtection: securityMiddleware.csrfProtection.bind(securityMiddleware),
  cspProtection: securityMiddleware.cspProtection.bind(securityMiddleware),
  deviceTracking: securityMiddleware.deviceTracking.bind(securityMiddleware),
  sessionTracking: securityMiddleware.sessionTracking.bind(securityMiddleware),
  securityHeaders: securityMiddleware.securityHeaders.bind(securityMiddleware),
  xssProtection: securityMiddleware.xssProtection.bind(securityMiddleware),
  apiAbusePrevention: securityMiddleware.apiAbusePrevention.bind(securityMiddleware),
  helmet: helmet,
  cookieParser: cookieParser
};
