const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class CSRFService {
  constructor() {
    this.tokens = new Map(); // In production, use Redis
    this.tokenExpiry = 24 * 60 * 60 * 1000; // 24 hours
  }

  /**
   * Generate a CSRF token
   */
  generateToken(sessionId) {
    try {
      const token = crypto.randomBytes(32).toString('hex');
      const timestamp = Date.now();
      
      this.tokens.set(sessionId, {
        token,
        timestamp,
        used: false
      });

      // Clean up expired tokens
      this.cleanupExpiredTokens();

      logger.info('csrf_token_generated', { sessionId, tokenLength: token.length });
      return token;
    } catch (error) {
      logger.error('csrf_token_generation_failed', { error: error.message });
      sentry.captureException(error);
      throw new Error('Failed to generate CSRF token');
    }
  }

  /**
   * Verify a CSRF token
   */
  verifyToken(sessionId, providedToken) {
    try {
      const tokenData = this.tokens.get(sessionId);
      
      if (!tokenData) {
        logger.warn('csrf_token_not_found', { sessionId });
        return false;
      }

      // Check if token has expired
      if (Date.now() - tokenData.timestamp > this.tokenExpiry) {
        this.tokens.delete(sessionId);
        logger.warn('csrf_token_expired', { sessionId });
        return false;
      }

      // Check if token has been used (prevent replay attacks)
      if (tokenData.used) {
        logger.warn('csrf_token_already_used', { sessionId });
        return false;
      }

      // Verify token matches
      if (tokenData.token !== providedToken) {
        logger.warn('csrf_token_mismatch', { sessionId });
        return false;
      }

      // Mark token as used
      tokenData.used = true;
      
      logger.info('csrf_token_verified', { sessionId });
      return true;
    } catch (error) {
      logger.error('csrf_token_verification_failed', { error: error.message });
      sentry.captureException(error);
      return false;
    }
  }

  /**
   * Clean up expired tokens
   */
  cleanupExpiredTokens() {
    try {
      const now = Date.now();
      for (const [sessionId, tokenData] of this.tokens.entries()) {
        if (now - tokenData.timestamp > this.tokenExpiry) {
          this.tokens.delete(sessionId);
        }
      }
    } catch (error) {
      logger.error('csrf_token_cleanup_failed', { error: error.message });
    }
  }

  /**
   * Generate nonce for CSP
   */
  generateNonce() {
    return crypto.randomBytes(16).toString('base64');
  }

  /**
   * Get or create session ID
   */
  getSessionId(req) {
    if (!req.session) {
      req.session = {};
    }
    
    if (!req.session.csrfSessionId) {
      req.session.csrfSessionId = crypto.randomBytes(16).toString('hex');
    }
    
    return req.session.csrfSessionId;
  }
}

module.exports = new CSRFService();
