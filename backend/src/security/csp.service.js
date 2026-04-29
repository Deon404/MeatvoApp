const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class CSPService {
  constructor() {
    this.nonces = new Map(); // In production, use Redis
    this.nonceExpiry = 5 * 60 * 1000; // 5 minutes
  }

  /**
   * Generate a nonce for CSP
   */
  generateNonce(requestId) {
    try {
      const nonce = crypto.randomBytes(16).toString('base64');
      const timestamp = Date.now();
      
      this.nonces.set(requestId, {
        nonce,
        timestamp
      });

      // Clean up expired nonces
      this.cleanupExpiredNonces();

      logger.info('csp_nonce_generated', { requestId });
      return nonce;
    } catch (error) {
      logger.error('csp_nonce_generation_failed', { error: error.message });
      sentry.captureException(error);
      throw new Error('Failed to generate CSP nonce');
    }
  }

  /**
   * Verify a nonce is still valid
   */
  verifyNonce(requestId, nonce) {
    try {
      const nonceData = this.nonces.get(requestId);
      
      if (!nonceData) {
        return false;
      }

      // Check if nonce has expired
      if (Date.now() - nonceData.timestamp > this.nonceExpiry) {
        this.nonces.delete(requestId);
        return false;
      }

      return nonceData.nonce === nonce;
    } catch (error) {
      logger.error('csp_nonce_verification_failed', { error: error.message });
      return false;
    }
  }

  /**
   * Clean up expired nonces
   */
  cleanupExpiredNonces() {
    try {
      const now = Date.now();
      for (const [requestId, nonceData] of this.nonces.entries()) {
        if (now - nonceData.timestamp > this.nonceExpiry) {
          this.nonces.delete(requestId);
        }
      }
    } catch (error) {
      logger.error('csp_nonce_cleanup_failed', { error: error.message });
    }
  }

  /**
   * Generate CSP header with nonce
   */
  generateCSPHeader(nonce, isDev = false) {
    const directives = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.gstatic.com https://www.googletagmanager.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' data: https: blob:",
      "connect-src 'self' https://api.meatvo.com wss://api.meatvo.com https://www.google-analytics.com",
      "frame-src 'none'",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      `script-src 'self' 'nonce-${nonce}' 'unsafe-inline' https://www.gstatic.com https://www.googletagmanager.com`,
      `style-src 'self' 'nonce-${nonce}' 'unsafe-inline' https://fonts.googleapis.com`,
      "frame-ancestors 'none'",
      "upgrade-insecure-requests"
    ];

    if (isDev) {
      directives.push(
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' 'nonce-${nonce}' https://www.gstatic.com",
        "connect-src 'self' ws://localhost:* wss://localhost:* https://localhost:*"
      );
    }

    return directives.join('; ');
  }

  /**
   * Get request ID from request
   */
  getRequestId(req) {
    return req.headers['x-request-id'] || 
           req.session?.requestId || 
           crypto.randomBytes(16).toString('hex');
  }
}

module.exports = new CSPService();
