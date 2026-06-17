const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');
const { fail } = require('../utils/response');

class PaymentSecurity {
  constructor() {
    this.paymentAttempts = new Map(); // In production, use Redis
    this.attemptWindow = 15 * 60 * 1000; // 15 minutes
    this.maxAttempts = 5;
    this.fraudDetection = this.fraudDetection.bind(this);
    this.paymentValidation = this.paymentValidation.bind(this);
  }

  /**
   * Generate secure payment signature
   */
  generatePaymentSignature(paymentData) {
    try {
      const { orderId, amount, currency, timestamp } = paymentData;
      const secretKey = process.env.CASHFREE_SECRET_KEY;
      
      // Create signature string
      const signatureString = `${orderId}|${amount}|${currency}|${timestamp}`;
      
      // Generate HMAC SHA256 signature
      const signature = crypto
        .createHmac('sha256', secretKey)
        .update(signatureString)
        .digest('hex');

      logger.info('payment_signature_generated', { 
        orderId, 
        amount,
        signatureLength: signature.length 
      });

      return signature;
    } catch (error) {
      logger.error('payment_signature_generation_failed', { 
        error: error.message,
        orderId: paymentData.orderId 
      });
      sentry.captureException(error, { orderId: paymentData.orderId });
      throw new Error('Failed to generate payment signature');
    }
  }

  /**
   * Verify payment signature
   */
  verifyPaymentSignature(paymentData, providedSignature) {
    try {
      const expectedSignature = this.generatePaymentSignature(paymentData);
      const isValid = crypto.timingSafeEqual(
        Buffer.from(expectedSignature, 'hex'),
        Buffer.from(providedSignature, 'hex')
      );

      logger.info('payment_signature_verified', { 
        orderId: paymentData.orderId,
        isValid 
      });

      return isValid;
    } catch (error) {
      logger.error('payment_signature_verification_failed', { 
        error: error.message,
        orderId: paymentData.orderId 
      });
      return false;
    }
  }

  /**
   * Fraud detection middleware
   */
  fraudDetection(req, res, next) {
    try {
      const userId = req.user?.id;
      const ip = req.ip || req.connection.remoteAddress;
      const userAgent = req.get('User-Agent') || '';
      const orderId = req.body?.orderId;

      if (!userId || !orderId) {
        return next();
      }

      const key = `${userId}:${orderId}`;
      const now = Date.now();
      const attempts = this.paymentAttempts.get(key) || { count: 0, lastAttempt: 0, suspicious: [] };

      // Check rate limiting
      if (now - attempts.lastAttempt < this.attemptWindow) {
        if (attempts.count >= this.maxAttempts) {
          logger.warn('payment_rate_limit_exceeded', {
            userId,
            orderId,
            ip,
            attempts: attempts.count
          });

          sentry.addBreadcrumb({
            message: 'Payment rate limit exceeded',
            category: 'payment',
            level: 'warning',
            data: { userId, orderId, ip }
          });

          return fail(res, 429, 'Too many payment attempts. Please try again later.', { code: 'PAYMENT_RATE_LIMIT' });
        }

        attempts.count++;
      } else {
        // Reset window
        attempts.count = 1;
        attempts.suspicious = [];
      }

      attempts.lastAttempt = now;
      this.paymentAttempts.set(key, attempts);

      // Check for suspicious patterns
      const suspiciousPatterns = this.checkSuspiciousPatterns(req, attempts);
      
      if (suspiciousPatterns.length > 0) {
        attempts.suspicious.push(...suspiciousPatterns);
        
        logger.warn('suspicious_payment_activity', {
          userId,
          orderId,
          ip,
          patterns: suspiciousPatterns
        });

        sentry.addBreadcrumb({
          message: 'Suspicious payment activity detected',
          category: 'payment',
          level: 'warning',
          data: { userId, orderId, ip, patterns: suspiciousPatterns }
        });

        // Block if too many suspicious patterns
        if (attempts.suspicious.length >= 3) {
          return fail(res, 403, 'Payment blocked due to suspicious activity', { code: 'PAYMENT_BLOCKED' });
        }
      }

      next();
    } catch (error) {
      logger.error('payment_fraud_detection_error', { error: error.message });
      sentry.captureException(error);
      next(); // Don't block on fraud detection errors
    }
  }

  /**
   * Check for suspicious payment patterns
   */
  checkSuspiciousPatterns(req, attempts) {
    const patterns = [];
    const ip = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent') || '';
    const { amount, orderId } = req.body;

    // Pattern 1: Multiple IPs for same user/order
    if (attempts.ips && attempts.ips.size > 1) {
      patterns.push('MULTIPLE_IPS');
    }

    // Pattern 2: Unusual amount variations
    if (attempts.amounts && attempts.amounts.size > 3) {
      patterns.push('UNUSUAL_AMOUNT_VARIATIONS');
    }

    // Pattern 3: Rapid successive attempts
    if (attempts.count > 3 && (Date.now() - attempts.firstAttempt) < 60000) {
      patterns.push('RAPID_ATTEMPTS');
    }

    // Pattern 4: Suspicious user agent
    const suspiciousUAs = /bot|crawler|spider|scraper|curl|wget|python|java|go/;
    if (suspiciousUAs.test(userAgent.toLowerCase())) {
      patterns.push('SUSPICIOUS_USER_AGENT');
    }

    // Pattern 5: High amount transactions
    if (amount > 50000) { // ₹50,000
      patterns.push('HIGH_AMOUNT');
    }

    // Pattern 6: Round number amounts (potential testing)
    if (amount % 1000 === 0 && amount > 10000) {
      patterns.push('ROUND_AMOUNT');
    }

    // Pattern 7: Order ID manipulation
    if (orderId && !/^[A-Za-z0-9_-]+$/.test(orderId)) {
      patterns.push('INVALID_ORDER_ID');
    }

    return patterns;
  }

  /**
   * Payment validation middleware
   */
  paymentValidation(req, res, next) {
    try {
      const { orderId, amount, currency, paymentMethod } = req.body;

      // Validate required fields
      if (!orderId || !amount || !currency) {
        return fail(res, 400, 'Missing required payment fields', { code: 'MISSING_FIELDS' });
      }

      // Validate amount
      if (typeof amount !== 'number' || amount <= 0 || amount > 100000) {
        return fail(res, 400, 'Invalid amount', { code: 'INVALID_AMOUNT' });
      }

      // Validate currency
      if (currency !== 'INR') {
        return fail(res, 400, 'Invalid currency', { code: 'INVALID_CURRENCY' });
      }

      // Validate order ID format
      if (!/^[A-Za-z0-9_-]{8,32}$/.test(orderId)) {
        return fail(res, 400, 'Invalid order ID format', { code: 'INVALID_ORDER_ID' });
      }

      // Validate payment method
      const validMethods = ['UPI', 'CARD', 'NETBANKING', 'WALLET'];
      if (paymentMethod && !validMethods.includes(paymentMethod.toUpperCase())) {
        return fail(res, 400, 'Invalid payment method', { code: 'INVALID_PAYMENT_METHOD' });
      }

      // Add timestamp for signature generation
      req.body.timestamp = Date.now();

      next();
    } catch (error) {
      logger.error('payment_validation_error', { error: error.message });
      sentry.captureException(error);
      return fail(res, 500, 'Payment validation failed');
    }
  }

  /**
   * Encrypt sensitive payment data
   */
  encryptPaymentData(data) {
    try {
      const algorithm = 'aes-256-gcm';
      const encKey = process.env.PAYMENT_ENCRYPTION_KEY;
      if (!encKey) throw new Error('PAYMENT_ENCRYPTION_KEY environment variable is required');
      const key = crypto.scryptSync(encKey, 'salt', 32);
      const iv = crypto.randomBytes(16);
      
      const cipher = crypto.createCipher(algorithm, key, iv);
      
      let encrypted = cipher.update(JSON.stringify(data), 'utf8', 'hex');
      encrypted += cipher.final('hex');
      
      const authTag = cipher.getAuthTag();
      
      return {
        encrypted,
        iv: iv.toString('hex'),
        authTag: authTag.toString('hex')
      };
    } catch (error) {
      logger.error('payment_data_encryption_failed', { error: error.message });
      throw new Error('Failed to encrypt payment data');
    }
  }

  /**
   * Decrypt sensitive payment data
   */
  decryptPaymentData(encryptedData) {
    try {
      const { encrypted, iv, authTag } = encryptedData;
      const algorithm = 'aes-256-gcm';
      const encKey = process.env.PAYMENT_ENCRYPTION_KEY;
      if (!encKey) throw new Error('PAYMENT_ENCRYPTION_KEY environment variable is required');
      const key = crypto.scryptSync(encKey, 'salt', 32);
      
      const decipher = crypto.createDecipher(algorithm, key, Buffer.from(iv, 'hex'));
      decipher.setAuthTag(Buffer.from(authTag, 'hex'));
      
      let decrypted = decipher.update(encrypted, 'hex', 'utf8');
      decrypted += decipher.final('utf8');
      
      return JSON.parse(decrypted);
    } catch (error) {
      logger.error('payment_data_decryption_failed', { error: error.message });
      throw new Error('Failed to decrypt payment data');
    }
  }

  /**
   * Clean up old payment attempts
   */
  cleanupPaymentAttempts() {
    try {
      const now = Date.now();
      for (const [key, attempts] of this.paymentAttempts.entries()) {
        if (now - attempts.lastAttempt > this.attemptWindow) {
          this.paymentAttempts.delete(key);
        }
      }
    } catch (error) {
      logger.error('payment_attempts_cleanup_failed', { error: error.message });
    }
  }

  /**
   * Get payment security statistics
   */
  getPaymentSecurityStats() {
    try {
      const stats = {
        totalAttempts: this.paymentAttempts.size,
        blockedAttempts: 0,
        suspiciousAttempts: 0,
        attemptsByUser: {}
      };

      for (const [key, attempts] of this.paymentAttempts.entries()) {
        const userId = key.split(':')[0];
        
        stats.attemptsByUser[userId] = (stats.attemptsByUser[userId] || 0) + 1;
        
        if (attempts.count >= this.maxAttempts) {
          stats.blockedAttempts++;
        }
        
        if (attempts.suspicious && attempts.suspicious.length > 0) {
          stats.suspiciousAttempts++;
        }
      }

      return stats;
    } catch (error) {
      logger.error('payment_security_stats_failed', { error: error.message });
      return {
        totalAttempts: 0,
        blockedAttempts: 0,
        suspiciousAttempts: 0,
        attemptsByUser: {}
      };
    }
  }
}

module.exports = new PaymentSecurity();
