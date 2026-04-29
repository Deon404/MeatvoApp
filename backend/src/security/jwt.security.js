const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class JWTSecurity {
  constructor() {
    this.blacklistedTokens = new Map(); // In production, use Redis
    this.tokenExpiryBuffer = 60; // 60 seconds buffer for token expiry
    this.maxTokenAge = 7 * 24 * 60 * 60 * 1000; // 7 days
    this.issuedTokens = new Map(); // Track issued tokens
  }

  /**
   * Generate secure JWT tokens with additional security
   */
  generateTokens(payload, options = {}) {
    try {
      const now = Date.now();
      const jti = crypto.randomBytes(16).toString('hex'); // JWT ID for tracking
      const iat = Math.floor(now / 1000);
      
      // Enhanced payload with security claims
      const enhancedPayload = {
        ...payload,
        iat,
        jti,
        iss: process.env.JWT_ISSUER || 'meatvo-api',
        aud: process.env.JWT_AUDIENCE || 'meatvo-client',
        type: payload.type || 'access',
        auth_time: iat,
        session_id: crypto.randomBytes(8).toString('hex')
      };

      // Access token with shorter expiry
      const accessTokenExpiry = options.accessTokenExpiry || '15m';
      const accessToken = jwt.sign(enhancedPayload, process.env.JWT_ACCESS_SECRET, {
        expiresIn: accessTokenExpiry,
        algorithm: 'HS256',
        issuer: enhancedPayload.iss,
        audience: enhancedPayload.aud,
        jwtid: jti
      });

      // Refresh token with longer expiry
      const refreshTokenPayload = {
        ...enhancedPayload,
        type: 'refresh',
        parent_jti: jti // Link refresh token to access token
      };

      const refreshTokenExpiry = options.refreshTokenExpiry || '7d';
      const refreshToken = jwt.sign(refreshTokenPayload, process.env.JWT_REFRESH_SECRET, {
        expiresIn: refreshTokenExpiry,
        algorithm: 'HS256',
        issuer: enhancedPayload.iss,
        audience: enhancedPayload.aud,
        jwtid: crypto.randomBytes(16).toString('hex')
      });

      // Track issued tokens
      this.trackIssuedToken(jti, {
        userId: payload.id,
        type: 'access',
        issuedAt: now,
        expiresAt: now + (15 * 60 * 1000), // 15 minutes
        ip: options.ip,
        userAgent: options.userAgent
      });

      const refreshJti = refreshTokenPayload.jti;
      this.trackIssuedToken(refreshJti, {
        userId: payload.id,
        type: 'refresh',
        issuedAt: now,
        expiresAt: now + (7 * 24 * 60 * 60 * 1000), // 7 days
        ip: options.ip,
        userAgent: options.userAgent
      });

      logger.info('jwt_tokens_generated', {
        userId: payload.id,
        accessTokenJti: jti,
        refreshTokenJti: refreshJti,
        ip: options.ip
      });

      return {
        accessToken,
        refreshToken,
        tokenType: 'Bearer',
        expiresIn: 15 * 60, // 15 minutes in seconds
        jti
      };
    } catch (error) {
      logger.error('jwt_token_generation_error', { error: error.message });
      sentry.captureException(error);
      throw new Error('Failed to generate JWT tokens');
    }
  }

  /**
   * Verify JWT token with enhanced security checks
   */
  verifyToken(token, secret, options = {}) {
    try {
      if (!token) {
        throw new Error('Token is required');
      }

      // Check if token is blacklisted
      const decoded = jwt.decode(token);
      if (decoded && decoded.jti && this.isTokenBlacklisted(decoded.jti)) {
        throw new Error('Token is blacklisted');
      }

      // Verify token with strict options
      const verifiedToken = jwt.verify(token, secret, {
        algorithms: ['HS256'],
        issuer: process.env.JWT_ISSUER || 'meatvo-api',
        audience: process.env.JWT_AUDIENCE || 'meatvo-client',
        clockTolerance: this.tokenExpiryBuffer,
        ...options
      });

      // Additional security checks
      this.performSecurityChecks(verifiedToken, options);

      return verifiedToken;
    } catch (error) {
      logger.error('jwt_token_verification_error', { 
        error: error.message,
        errorName: error.name 
      });

      // Add security context to Sentry
      sentry.addBreadcrumb({
        message: 'JWT token verification failed',
        category: 'auth',
        level: 'warning',
        data: {
          error: error.message,
          errorName: error.name
        }
      });

      throw error;
    }
  }

  /**
   * Perform additional security checks on verified token
   */
  performSecurityChecks(token, options = {}) {
    try {
      // Check token age
      const now = Date.now();
      const tokenAge = now - (token.iat * 1000);
      
      if (tokenAge > this.maxTokenAge) {
        throw new Error('Token is too old');
      }

      // Check if token was issued before user password change
      if (options.passwordChangedAt && token.iat < options.passwordChangedAt) {
        throw new Error('Token issued before password change');
      }

      // Check session validity
      if (token.session_id && !this.isSessionValid(token.session_id, token.id)) {
        throw new Error('Invalid session');
      }

      // Rate limiting for token verification
      const key = `token_verify:${token.id}`;
      const count = (this.issuedTokens.get(key) || 0) + 1;
      this.issuedTokens.set(key, count);

      if (count > 10) { // Max 10 verifications per minute
        throw new Error('Too many token verification attempts');
      }

      // Clean up old rate limit entries
      setTimeout(() => {
        const currentCount = this.issuedTokens.get(key) || 0;
        if (currentCount <= 1) {
          this.issuedTokens.delete(key);
        } else {
          this.issuedTokens.set(key, currentCount - 1);
        }
      }, 60 * 1000);
    } catch (error) {
      logger.error('jwt_security_checks_failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Blacklist a token
   */
  blacklistToken(jti, reason = 'Logout') {
    try {
      this.blacklistedTokens.set(jti, {
        blacklistedAt: Date.now(),
        reason,
        expiresAt: Date.now() + (7 * 24 * 60 * 60 * 1000) // 7 days
      });

      logger.info('jwt_token_blacklisted', { jti, reason });

      sentry.addBreadcrumb({
        message: 'JWT token blacklisted',
        category: 'auth',
        level: 'info',
        data: { jti, reason }
      });
    } catch (error) {
      logger.error('jwt_token_blacklist_error', { error: error.message });
    }
  }

  /**
   * Check if token is blacklisted
   */
  isTokenBlacklisted(jti) {
    try {
      const blacklistData = this.blacklistedTokens.get(jti);
      
      if (!blacklistData) {
        return false;
      }

      // Check if blacklist entry has expired
      if (Date.now() > blacklistData.expiresAt) {
        this.blacklistedTokens.delete(jti);
        return false;
      }

      return true;
    } catch (error) {
      logger.error('jwt_blacklist_check_error', { error: error.message });
      return false;
    }
  }

  /**
   * Track issued tokens for monitoring
   */
  trackIssuedToken(jti, tokenData) {
    try {
      this.issuedTokens.set(jti, tokenData);
      
      // Clean up expired tokens
      this.cleanupExpiredTokens();
    } catch (error) {
      logger.error('jwt_token_tracking_error', { error: error.message });
    }
  }

  /**
   * Check if session is valid
   */
  isSessionValid(sessionId, userId) {
    try {
      // In production, check against session store
      // For now, assume session is valid
      return true;
    } catch (error) {
      logger.error('jwt_session_validation_error', { error: error.message });
      return false;
    }
  }

  /**
   * Refresh access token
   */
  refreshAccessToken(refreshToken, options = {}) {
    try {
      const decoded = this.verifyToken(refreshToken, process.env.JWT_REFRESH_SECRET);
      
      if (decoded.type !== 'refresh') {
        throw new Error('Invalid refresh token type');
      }

      // Check if refresh token is blacklisted
      if (this.isTokenBlacklisted(decoded.jti)) {
        throw new Error('Refresh token is blacklisted');
      }

      // Blacklist the old refresh token
      this.blacklistToken(decoded.jti, 'Token refresh');

      // Generate new tokens
      const newTokens = this.generateTokens({
        id: decoded.id,
        phone: decoded.phone,
        email: decoded.email,
        role: decoded.role
      }, options);

      logger.info('jwt_token_refreshed', {
        userId: decoded.id,
        oldJti: decoded.jti,
        newJti: newTokens.jti
      });

      return newTokens;
    } catch (error) {
      logger.error('jwt_token_refresh_error', { error: error.message });
      throw error;
    }
  }

  /**
   * Revoke all user tokens
   */
  revokeAllUserTokens(userId) {
    try {
      let revokedCount = 0;
      
      for (const [jti, tokenData] of this.issuedTokens.entries()) {
        if (tokenData.userId === userId) {
          this.blacklistToken(jti, 'User token revocation');
          revokedCount++;
        }
      }

      logger.info('all_user_tokens_revoked', { userId, revokedCount });

      sentry.addBreadcrumb({
        message: 'All user tokens revoked',
        category: 'auth',
        level: 'info',
        data: { userId, revokedCount }
      });

      return revokedCount;
    } catch (error) {
      logger.error('user_token_revocation_error', { error: error.message, userId });
      return 0;
    }
  }

  /**
   * Clean up expired tokens
   */
  cleanupExpiredTokens() {
    try {
      const now = Date.now();
      
      // Clean up issued tokens
      for (const [jti, tokenData] of this.issuedTokens.entries()) {
        if (now > tokenData.expiresAt) {
          this.issuedTokens.delete(jti);
        }
      }

      // Clean up blacklisted tokens
      for (const [jti, blacklistData] of this.blacklistedTokens.entries()) {
        if (now > blacklistData.expiresAt) {
          this.blacklistedTokens.delete(jti);
        }
      }

      // Clean up rate limit entries
      for (const [key, count] of this.issuedTokens.entries()) {
        if (key.startsWith('token_verify:') && count <= 0) {
          this.issuedTokens.delete(key);
        }
      }
    } catch (error) {
      logger.error('jwt_token_cleanup_error', { error: error.message });
    }
  }

  /**
   * Get JWT security statistics
   */
  getSecurityStats() {
    try {
      const stats = {
        issuedTokens: this.issuedTokens.size,
        blacklistedTokens: this.blacklistedTokens.size,
        tokensByType: {},
        tokensByUser: {},
        averageTokenAge: 0
      };

      let totalAge = 0;
      let tokenCount = 0;

      for (const [jti, tokenData] of this.issuedTokens.entries()) {
        if (tokenData.type) {
          stats.tokensByType[tokenData.type] = (stats.tokensByType[tokenData.type] || 0) + 1;
        }
        
        if (tokenData.userId) {
          stats.tokensByUser[tokenData.userId] = (stats.tokensByUser[tokenData.userId] || 0) + 1;
        }

        const age = Date.now() - tokenData.issuedAt;
        totalAge += age;
        tokenCount++;
      }

      if (tokenCount > 0) {
        stats.averageTokenAge = totalAge / tokenCount;
      }

      return stats;
    } catch (error) {
      logger.error('jwt_security_stats_error', { error: error.message });
      return {
        issuedTokens: 0,
        blacklistedTokens: 0,
        tokensByType: {},
        tokensByUser: {},
        averageTokenAge: 0
      };
    }
  }

  /**
   * Validate token format
   */
  validateTokenFormat(token) {
    try {
      if (!token || typeof token !== 'string') {
        return false;
      }

      const parts = token.split('.');
      if (parts.length !== 3) {
        return false;
      }

      // Try to decode header and payload
      const header = JSON.parse(Buffer.from(parts[0], 'base64').toString());
      const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());

      return header.typ === 'JWT' && payload;
    } catch (error) {
      return false;
    }
  }
}

module.exports = new JWTSecurity();
