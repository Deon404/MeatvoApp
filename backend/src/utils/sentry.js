const Sentry = require('@sentry/node');
const { logger } = require('./logger');

class SentryService {
  constructor() {
    this.isInitialized = false;
  }

  initialize() {
    try {
      const dsn = process.env.SENTRY_DSN;
      
      if (!dsn) {
        logger.warn('sentry_not_configured', { message: 'SENTRY_DSN not found in environment variables' });
        return;
      }

      Sentry.init({
        dsn,
        environment: process.env.NODE_ENV || 'development',
        
        // Set traces sample rate for performance monitoring
        tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 0.0,
        
        // Enable sampling for errors
        sampleRate: 1.0,
        
        // Release information
        release: process.env.npm_package_version || '1.0.0',
        
        // Server name
        serverName: process.env.HOSTNAME || 'meatvo-api',
        
        // Before send hook for filtering
        beforeSend: this.filterEvent.bind(this),
        
        // Integrations
        integrations: [
          // Enable HTTP requests tracing
          new Sentry.Integrations.Http({ tracing: true }),
          
          // Enable Express.js error handling
          new Sentry.Integrations.Express({ app: null }),
          
          // Enable database query tracing
          new Sentry.Integrations.Postgres(),
        ],
        
        // Ignore specific errors
        ignoreErrors: [
          // Ignore validation errors
          /ValidationError/i,
          /CastError/i,
          
          // Ignore authentication errors
          /UnauthorizedError/i,
          /JsonWebTokenError/i,
          /TokenExpiredError/i,
          
          // Ignore network errors
          /ECONNREFUSED/i,
          /ETIMEDOUT/i,
          /ENOTFOUND/i,
        ],
        
        // Ignore specific URLs
        denyUrls: [
          // Chrome extensions
          /extensions\//i,
          /^chrome:\/\//i,
          /^chrome-extension:\/\//i,
          
          // Local files
          /^file:\/\//i,
          
          // Third-party scripts
          /google-analytics/i,
          /googletagmanager/i,
          /facebook\.net/i,
        ],
      });

      this.isInitialized = true;
      logger.info('sentry_initialized', { 
        environment: process.env.NODE_ENV,
        dsn: dsn.replace(/\/\/.*@/, '//***@') // Hide sensitive part
      });
    } catch (error) {
      logger.error('sentry_initialization_failed', { error: error.message });
    }
  }

  filterEvent(event, hint) {
    try {
      // Remove sensitive data from request
      if (event.request && event.request.headers) {
        // Remove sensitive headers
        const sensitiveHeaders = ['authorization', 'cookie', 'x-api-key'];
        sensitiveHeaders.forEach(header => {
          delete event.request.headers[header];
          delete event.request.headers[header.toUpperCase()];
        });
      }

      // Remove sensitive data from user
      if (event.user) {
        delete event.user.email;
        delete event.user.phone;
      }

      // Filter out PII from extra data
      if (event.extra) {
        Object.keys(event.extra).forEach(key => {
          if (typeof event.extra[key] === 'string') {
            // Remove potential PII
            event.extra[key] = event.extra[key].replace(/\b\d{10,}\b/g, '[PHONE_NUMBER]');
            event.extra[key] = event.extra[key].replace(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, '[EMAIL]');
          }
        });
      }

      // Add custom context
      event.contexts = {
        ...event.contexts,
        app: {
          name: 'meatvo-api',
          version: process.env.npm_package_version || '1.0.0',
          environment: process.env.NODE_ENV || 'development'
        },
        runtime: {
          name: 'node',
          version: process.version
        }
      };

      return event;
    } catch (error) {
      logger.error('sentry_filter_failed', { error: error.message });
      return event;
    }
  }

  captureException(error, context = {}) {
    if (!this.isInitialized) {
      logger.error('sentry_not_initialized', { error: error.message });
      return;
    }

    try {
      // Add context to the error
      if (Object.keys(context).length > 0) {
        Sentry.withScope((scope) => {
          Object.entries(context).forEach(([key, value]) => {
            scope.setContext(key, value);
          });
          Sentry.captureException(error);
        });
      } else {
        Sentry.captureException(error);
      }

      logger.info('sentry_exception_captured', { 
        error: error.message,
        stack: error.stack?.substring(0, 200)
      });
    } catch (sentryError) {
      logger.error('sentry_capture_failed', { 
        error: sentryError.message,
        originalError: error.message 
      });
    }
  }

  captureMessage(message, level = 'info', context = {}) {
    if (!this.isInitialized) {
      logger.warn('sentry_not_initialized', { message });
      return;
    }

    try {
      if (Object.keys(context).length > 0) {
        Sentry.withScope((scope) => {
          Object.entries(context).forEach(([key, value]) => {
            scope.setContext(key, value);
          });
          Sentry.captureMessage(message, level);
        });
      } else {
        Sentry.captureMessage(message, level);
      }

      logger.info('sentry_message_captured', { message, level });
    } catch (error) {
      logger.error('sentry_message_failed', { 
        error: error.message,
        originalMessage: message 
      });
    }
  }

  setUser(user) {
    if (!this.isInitialized) {
      return;
    }

    try {
      // Only send non-sensitive user data
      const safeUser = {
        id: user.id,
        role: user.role,
        username: user.username
      };

      Sentry.setUser(safeUser);
      logger.info('sentry_user_set', { userId: user.id });
    } catch (error) {
      logger.error('sentry_set_user_failed', { error: error.message });
    }
  }

  clearUser() {
    if (!this.isInitialized) {
      return;
    }

    try {
      Sentry.setUser(null);
      logger.info('sentry_user_cleared');
    } catch (error) {
      logger.error('sentry_clear_user_failed', { error: error.message });
    }
  }

  addBreadcrumb(breadcrumb) {
    if (!this.isInitialized) {
      return;
    }

    try {
      Sentry.addBreadcrumb({
        ...breadcrumb,
        timestamp: Math.floor(Date.now() / 1000)
      });
    } catch (error) {
      logger.error('sentry_breadcrumb_failed', { error: error.message });
    }
  }

  setTransactionName(name) {
    if (!this.isInitialized) {
      return;
    }

    try {
      Sentry.setTag('transaction', name);
    } catch (error) {
      logger.error('sentry_transaction_failed', { error: error.message });
    }
  }

  setTag(key, value) {
    if (!this.isInitialized) {
      return;
    }

    try {
      Sentry.setTag(key, value);
    } catch (error) {
      logger.error('sentry_tag_failed', { error: error.message });
    }
  }

  // Performance monitoring
  startTransaction(name, op = 'http.server') {
    if (!this.isInitialized) {
      return null;
    }

    try {
      return Sentry.startTransaction({
        name,
        op
      });
    } catch (error) {
      logger.error('sentry_transaction_start_failed', { error: error.message });
      return null;
    }
  }

  finishTransaction(transaction, status = 'ok') {
    if (!this.isInitialized || !transaction) {
      return;
    }

    try {
      transaction.setStatus(status);
      transaction.finish();
    } catch (error) {
      logger.error('sentry_transaction_finish_failed', { error: error.message });
    }
  }

  // Express.js error handler middleware
  errorHandler() {
    return (error, req, res, next) => {
      // Log the error normally
      logger.error('express_error', {
        error: error.message,
        stack: error.stack,
        url: req.url,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });

      // Add request context
      const context = {
        request: {
          url: req.url,
          method: req.method,
          headers: req.headers,
          query: req.query,
          body: req.body
        },
        user: req.user
      };

      // Capture in Sentry
      this.captureException(error, context);

      // Continue to next error handler
      next(error);
    };
  }

  // Request handler for adding breadcrumbs
  requestHandler() {
    return (req, res, next) => {
      // Add breadcrumb for request
      this.addBreadcrumb({
        message: `${req.method} ${req.url}`,
        category: 'http',
        level: 'info',
        data: {
          method: req.method,
          url: req.url,
          userAgent: req.get('User-Agent'),
          ip: req.ip
        }
      });

      next();
    };
  }

  // Get Sentry client for advanced usage
  getClient() {
    return this.isInitialized ? Sentry.getCurrentHub().getClient() : null;
  }

  // Test Sentry configuration
  async test() {
    if (!this.isInitialized) {
      return { success: false, error: 'Sentry not initialized' };
    }

    try {
      // Send a test event
      const testId = `test_${Date.now()}`;
      this.captureMessage(`Sentry test message - ${testId}`, 'info');
      
      logger.info('sentry_test_sent', { testId });
      return { success: true, testId };
    } catch (error) {
      logger.error('sentry_test_failed', { error: error.message });
      return { success: false, error: error.message };
    }
  }
}

module.exports = new SentryService();
