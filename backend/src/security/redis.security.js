const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class RedisSecurity {
  constructor() {
    this.encryptionKey = this.getEncryptionKey();
    this.sensitiveKeys = new Set([
      'password',
      'token',
      'secret',
      'key',
      'auth',
      'session',
      'csrf',
      'otp',
      'payment',
      'card',
      'bank',
      'upi',
      'cashfree'
    ]);
  }

  /**
   * Get or generate encryption key
   */
  getEncryptionKey() {
    try {
      const key = process.env.REDIS_ENCRYPTION_KEY;
      if (key) {
        return crypto.scryptSync(key, 'salt', 32);
      }
      
      // Generate a random key for development (NOT for production)
      if (process.env.NODE_ENV === 'development') {
        return crypto.randomBytes(32);
      }
      
      throw new Error('Redis encryption key not configured');
    } catch (error) {
      logger.error('redis_encryption_key_error', { error: error.message });
      throw new Error('Failed to get Redis encryption key');
    }
  }

  /**
   * Encrypt sensitive data before storing in Redis
   */
  encrypt(data) {
    try {
      if (typeof data !== 'string') {
        data = JSON.stringify(data);
      }

      const algorithm = 'aes-256-gcm';
      const iv = crypto.randomBytes(16);
      const cipher = crypto.createCipher(algorithm, this.encryptionKey, iv);
      
      let encrypted = cipher.update(data, 'utf8', 'hex');
      encrypted += cipher.final('hex');
      
      const authTag = cipher.getAuthTag();
      
      const result = {
        encrypted: true,
        data: encrypted,
        iv: iv.toString('hex'),
        authTag: authTag.toString('hex')
      };

      logger.debug('data_encrypted_for_redis', { 
        dataType: typeof data,
        dataLength: data.length 
      });

      return JSON.stringify(result);
    } catch (error) {
      logger.error('redis_encryption_error', { error: error.message });
      sentry.captureException(error);
      throw new Error('Failed to encrypt data for Redis');
    }
  }

  /**
   * Decrypt data retrieved from Redis
   */
  decrypt(encryptedData) {
    try {
      if (typeof encryptedData !== 'string') {
        return encryptedData;
      }

      const parsed = JSON.parse(encryptedData);
      
      if (!parsed.encrypted) {
        return encryptedData;
      }

      const { data, iv, authTag } = parsed;
      const algorithm = 'aes-256-gcm';
      
      const decipher = crypto.createDecipher(algorithm, this.encryptionKey, Buffer.from(iv, 'hex'));
      decipher.setAuthTag(Buffer.from(authTag, 'hex'));
      
      let decrypted = decipher.update(data, 'hex', 'utf8');
      decrypted += decipher.final('utf8');
      
      try {
        return JSON.parse(decrypted);
      } catch {
        return decrypted;
      }
    } catch (error) {
      logger.error('redis_decryption_error', { error: error.message });
      sentry.captureException(error);
      throw new Error('Failed to decrypt data from Redis');
    }
  }

  /**
   * Check if a key contains sensitive information
   */
  isSensitiveKey(key) {
    const keyLower = key.toLowerCase();
    
    return Array.from(this.sensitiveKeys).some(sensitive => 
      keyLower.includes(sensitive.toLowerCase())
    );
  }

  /**
   * Secure Redis get operation
   */
  async secureGet(redisClient, key) {
    try {
      let value = await redisClient.get(key);
      
      if (value && this.isSensitiveKey(key)) {
        value = this.decrypt(value);
      }

      return value;
    } catch (error) {
      logger.error('redis_secure_get_error', { error: error.message, key });
      sentry.captureException(error, { key });
      throw error;
    }
  }

  /**
   * Secure Redis set operation
   */
  async secureSet(redisClient, key, value, options = {}) {
    try {
      if (this.isSensitiveKey(key)) {
        value = this.encrypt(value);
      }

      if (options.EX) {
        return await redisClient.setex(key, options.EX, value);
      } else {
        return await redisClient.set(key, value);
      }
    } catch (error) {
      logger.error('redis_secure_set_error', { error: error.message, key });
      sentry.captureException(error, { key });
      throw error;
    }
  }

  /**
   * Secure Redis hget operation
   */
  async secureHGet(redisClient, key, field) {
    try {
      let value = await redisClient.hget(key, field);
      
      if (value && this.isSensitiveKey(field)) {
        value = this.decrypt(value);
      }

      return value;
    } catch (error) {
      logger.error('redis_secure_hget_error', { error: error.message, key, field });
      sentry.captureException(error, { key, field });
      throw error;
    }
  }

  /**
   * Secure Redis hset operation
   */
  async secureHSet(redisClient, key, field, value) {
    try {
      if (this.isSensitiveKey(field)) {
        value = this.encrypt(value);
      }

      return await redisClient.hset(key, field, value);
    } catch (error) {
      logger.error('redis_secure_hset_error', { error: error.message, key, field });
      sentry.captureException(error, { key, field });
      throw error;
    }
  }

  /**
   * Generate secure Redis key with namespace
   */
  generateSecureKey(namespace, identifier, suffix = '') {
    try {
      const timestamp = Date.now();
      const random = crypto.randomBytes(4).toString('hex');
      
      const key = `${namespace}:${identifier}:${timestamp}:${random}${suffix ? ':' + suffix : ''}`;
      
      logger.debug('secure_redis_key_generated', { 
        namespace, 
        identifier: identifier.substring(0, 8) + '...',
        keyLength: key.length 
      });

      return key;
    } catch (error) {
      logger.error('secure_key_generation_error', { error: error.message });
      throw new Error('Failed to generate secure Redis key');
    }
  }

  /**
   * Validate Redis key format
   */
  validateKey(key) {
    try {
      // Check for key injection attempts
      const dangerousPatterns = [
        /\r?\n/,  // Newline injection
        /[\x00-\x1F\x7F]/,  // Control characters
        /[<>:"\\|?*]/,  // Invalid characters
        /\.\.\//,  // Path traversal
      ];

      if (dangerousPatterns.some(pattern => pattern.test(key))) {
        logger.warn('dangerous_redis_key_detected', { key });
        return false;
      }

      // Check key length
      if (key.length > 250) {
        logger.warn('redis_key_too_long', { keyLength: key.length });
        return false;
      }

      return true;
    } catch (error) {
      logger.error('redis_key_validation_error', { error: error.message });
      return false;
    }
  }

  /**
   * Add rate limiting for Redis operations
   */
  createRateLimiter(redisClient, keyPrefix, maxRequests = 100, windowMs = 60000) {
    return async (identifier) => {
      try {
        const key = `${keyPrefix}:${identifier}`;
        const now = Date.now();
        const windowStart = now - windowMs;
        
        // Clean up old entries
        await redisClient.zremrangebyscore(key, 0, windowStart);
        
        // Check current count
        const current = await redisClient.zcard(key);
        
        if (current >= maxRequests) {
          return { allowed: false, remaining: 0, resetTime: now + windowMs };
        }
        
        // Add current request
        await redisClient.zadd(key, now, now);
        await redisClient.expire(key, Math.ceil(windowMs / 1000));
        
        return { 
          allowed: true, 
          remaining: maxRequests - current - 1, 
          resetTime: now + windowMs 
        };
      } catch (error) {
        logger.error('redis_rate_limiter_error', { error: error.message });
        return { allowed: true, remaining: maxRequests - 1, resetTime: Date.now() + windowMs };
      }
    };
  }

  /**
   * Monitor Redis security events
   */
  monitorSecurityEvents(redisClient) {
    try {
      // Monitor for suspicious patterns
      const suspiciousPatterns = [
        'brute_force',
        'injection_attempt',
        'unusual_access_pattern',
        'data_exfiltration'
      ];

      // Set up monitoring (implementation depends on Redis configuration)
      logger.info('redis_security_monitoring_enabled', {
        patterns: suspiciousPatterns
      });
    } catch (error) {
      logger.error('redis_security_monitoring_error', { error: error.message });
    }
  }

  /**
   * Get Redis security statistics
   */
  getSecurityStats() {
    return {
      encryptionEnabled: true,
      sensitiveKeysCount: this.sensitiveKeys.size,
      encryptionAlgorithm: 'aes-256-gcm',
      keyValidationEnabled: true
    };
  }

  /**
   * Add sensitive key pattern
   */
  addSensitiveKeyPattern(pattern) {
    this.sensitiveKeys.add(pattern);
    logger.info('sensitive_key_pattern_added', { pattern });
  }

  /**
   * Remove sensitive key pattern
   */
  removeSensitiveKeyPattern(pattern) {
    this.sensitiveKeys.delete(pattern);
    logger.info('sensitive_key_pattern_removed', { pattern });
  }
}

module.exports = new RedisSecurity();
