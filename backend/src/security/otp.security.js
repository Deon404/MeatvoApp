const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class OTPSecurity {
  constructor() {
    this.otpAttempts = new Map(); // In production, use Redis
    this.otpWindow = 10 * 60 * 1000; // 10 minutes
    this.maxAttempts = 3;
    this.maxOTPsPerHour = 10;
    this.blockDuration = 30 * 60 * 1000; // 30 minutes
    this.generateSecureOTP = this.generateSecureOTP.bind(this);
    this.verifyOTP = this.verifyOTP.bind(this);
    this.rateLimitOTP = this.rateLimitOTP.bind(this);
  }

  /**
   * Generate cryptographically secure OTP
   */
  generateSecureOTP(phone, options = {}) {
    try {
      const length = options.length || 6;
      const otp = crypto.randomInt(0, Math.pow(10, length)).toString().padStart(length, '0');
      
      // Create OTP hash for secure storage
      const otpHash = this.hashOTP(phone, otp);
      const otpId = crypto.randomBytes(16).toString('hex');
      
      const otpData = {
        id: otpId,
        phone: this.normalizePhone(phone),
        hash: otpHash,
        attempts: 0,
        createdAt: Date.now(),
        expiresAt: Date.now() + this.otpWindow,
        used: false
      };

      // Store OTP data
      this.otpAttempts.set(otpId, otpData);

      // Track OTP generation rate
      this.trackOTPGeneration(phone);

      logger.info('secure_otp_generated', {
        otpId,
        phone: this.maskPhone(phone),
        expiresAt: otpData.expiresAt
      });

      return {
        otpId,
        otp: process.env.NODE_ENV === 'development' ? otp : undefined, // Only show OTP in development
        expiresIn: Math.floor(this.otpWindow / 1000),
        expiresAt: otpData.expiresAt
      };
    } catch (error) {
      logger.error('otp_generation_error', { error: error.message, phone: this.maskPhone(phone) });
      sentry.captureException(error, { phone: this.maskPhone(phone) });
      throw new Error('Failed to generate OTP');
    }
  }

  /**
   * Verify OTP with enhanced security
   */
  verifyOTP(otpId, providedOTP, phone) {
    try {
      const otpData = this.otpAttempts.get(otpId);
      
      if (!otpData) {
        logger.warn('otp_not_found', { otpId, phone: this.maskPhone(phone) });
        return { valid: false, reason: 'OTP not found or expired' };
      }

      // Check if OTP has expired
      if (Date.now() > otpData.expiresAt) {
        this.otpAttempts.delete(otpId);
        logger.warn('otp_expired', { otpId, phone: this.maskPhone(phone) });
        return { valid: false, reason: 'OTP has expired' };
      }

      // Check if OTP has been used
      if (otpData.used) {
        logger.warn('otp_already_used', { otpId, phone: this.maskPhone(phone) });
        return { valid: false, reason: 'OTP has already been used' };
      }

      // Check maximum attempts
      if (otpData.attempts >= this.maxAttempts) {
        logger.warn('otp_max_attempts_reached', { 
          otpId, 
          phone: this.maskPhone(phone),
          attempts: otpData.attempts 
        });
        return { valid: false, reason: 'Maximum attempts reached' };
      }

      // Verify phone number matches
      if (otpData.phone !== this.normalizePhone(phone)) {
        otpData.attempts++;
        logger.warn('otp_phone_mismatch', { 
          otpId, 
          expectedPhone: this.maskPhone(otpData.phone),
          providedPhone: this.maskPhone(phone)
        });
        return { valid: false, reason: 'Phone number mismatch' };
      }

      // Verify OTP hash
      const providedHash = this.hashOTP(phone, providedOTP);
      const isValid = crypto.timingSafeEqual(
        Buffer.from(otpData.hash, 'hex'),
        Buffer.from(providedHash, 'hex')
      );

      if (!isValid) {
        otpData.attempts++;
        logger.warn('otp_verification_failed', { 
          otpId, 
          phone: this.maskPhone(phone),
          attempts: otpData.attempts,
          remainingAttempts: this.maxAttempts - otpData.attempts
        });

        sentry.addBreadcrumb({
          message: 'OTP verification failed',
          category: 'auth',
          level: 'warning',
          data: {
            otpId,
            phone: this.maskPhone(phone),
            attempts: otpData.attempts
          }
        });

        return { 
          valid: false, 
          reason: 'Invalid OTP',
          remainingAttempts: this.maxAttempts - otpData.attempts
        };
      }

      // Mark OTP as used
      otpData.used = true;
      otpData.usedAt = Date.now();

      logger.info('otp_verified_successfully', {
        otpId,
        phone: this.maskPhone(phone),
        attempts: otpData.attempts
      });

      sentry.addBreadcrumb({
        message: 'OTP verified successfully',
        category: 'auth',
        level: 'info',
        data: {
          otpId,
          phone: this.maskPhone(phone)
        }
      });

      return { valid: true, attempts: otpData.attempts };
    } catch (error) {
      logger.error('otp_verification_error', { error: error.message, otpId });
      sentry.captureException(error, { otpId });
      return { valid: false, reason: 'Verification failed' };
    }
  }

  /**
   * Rate limiting for OTP generation
   */
  rateLimitOTP(phone) {
    try {
      const normalizedPhone = this.normalizePhone(phone);
      const now = Date.now();
      const key = `otp_rate:${normalizedPhone}`;
      
      const rateData = this.otpAttempts.get(key) || {
        count: 0,
        windowStart: now,
        blockedUntil: null
      });

      // Check if user is blocked
      if (rateData.blockedUntil && now < rateData.blockedUntil) {
        const remainingTime = Math.ceil((rateData.blockedUntil - now) / 1000);
        
        logger.warn('otp_blocked', {
          phone: this.maskPhone(phone),
          blockedUntil: rateData.blockedUntil,
          remainingTime
        });

        return {
          allowed: false,
          reason: 'Too many OTP requests. Please try again later.',
          retryAfter: remainingTime
        };
      }

      // Reset window if needed
      if (now - rateData.windowStart > 60 * 60 * 1000) { // 1 hour
        rateData.count = 0;
        rateData.windowStart = now;
      }

      // Check hourly limit
      if (rateData.count >= this.maxOTPsPerHour) {
        rateData.blockedUntil = now + this.blockDuration;
        this.otpAttempts.set(key, rateData);

        logger.warn('otp_hourly_limit_exceeded', {
          phone: this.maskPhone(phone),
          count: rateData.count,
          blockedUntil: rateData.blockedUntil
        });

        return {
          allowed: false,
          reason: 'Hourly OTP limit exceeded',
          retryAfter: Math.ceil(this.blockDuration / 1000)
        };
      }

      // Increment count
      rateData.count++;
      this.otpAttempts.set(key, rateData);

      return { allowed: true };
    } catch (error) {
      logger.error('otp_rate_limiting_error', { error: error.message });
      return { allowed: true }; // Allow on error
    }
  }

  /**
   * Track OTP generation for monitoring
   */
  trackOTPGeneration(phone) {
    try {
      const normalizedPhone = this.normalizePhone(phone);
      const now = Date.now();
      const key = `otp_gen:${normalizedPhone}`;
      
      const genData = this.otpAttempts.get(key) || {
        count: 0,
        lastGeneration: null,
        suspiciousPatterns: []
      };

      // Check for suspicious patterns
      if (genData.lastGeneration && now - genData.lastGeneration < 5000) {
        genData.suspiciousPatterns.push('RAPID_GENERATION');
      }

      genData.count++;
      genData.lastGeneration = now;
      this.otpAttempts.set(key, genData);

      // Alert on suspicious activity
      if (genData.suspiciousPatterns.length > 0) {
        logger.warn('suspicious_otp_activity', {
          phone: this.maskPhone(phone),
          patterns: genData.suspiciousPatterns,
          count: genData.count
        });

        sentry.addBreadcrumb({
          message: 'Suspicious OTP activity detected',
          category: 'security',
          level: 'warning',
          data: {
            phone: this.maskPhone(phone),
            patterns: genData.suspiciousPatterns
          }
        });
      }
    } catch (error) {
      logger.error('otp_tracking_error', { error: error.message });
    }
  }

  /**
   * Hash OTP for secure storage
   */
  hashOTP(phone, otp) {
    const secret = process.env.OTP_HASH_SECRET;
    if (!secret) {
      throw new Error('OTP hash secret not configured');
    }

    const data = `${this.normalizePhone(phone)}:${otp}`;
    return crypto.createHmac('sha256', secret).update(data).digest('hex');
  }

  /**
   * Normalize phone number
   */
  normalizePhone(phone) {
    if (!phone || typeof phone !== 'string') {
      return phone;
    }

    // Remove all non-digit characters
    const digits = phone.replace(/\D/g, '');
    
    // Add country code if missing (assuming India)
    if (digits.length === 10 && !phone.startsWith('+')) {
      return `+91${digits}`;
    }

    return phone;
  }

  /**
   * Mask phone number for logging
   */
  maskPhone(phone) {
    if (!phone || typeof phone !== 'string') {
      return phone;
    }

    const normalized = this.normalizePhone(phone);
    if (normalized.length <= 4) {
      return normalized;
    }

    return normalized.substring(0, 3) + '******' + normalized.substring(normalized.length - 2);
  }

  /**
   * Clean up expired OTPs
   */
  cleanupExpiredOTPs() {
    try {
      const now = Date.now();
      let cleanedCount = 0;
      
      for (const [key, otpData] of this.otpAttempts.entries()) {
        if (otpData.expiresAt && now > otpData.expiresAt) {
          this.otpAttempts.delete(key);
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        logger.info('expired_otps_cleaned', { count: cleanedCount });
      }
    } catch (error) {
      logger.error('otp_cleanup_error', { error: error.message });
    }
  }

  /**
   * Get OTP security statistics
   */
  getSecurityStats() {
    try {
      const stats = {
        totalOTPs: 0,
        activeOTPs: 0,
        usedOTPs: 0,
        expiredOTPs: 0,
        otpsByPhone: {},
        averageAttempts: 0,
        suspiciousActivities: 0
      };

      let totalAttempts = 0;
      let otpCount = 0;
      const now = Date.now();

      for (const [key, data] of this.otpAttempts.entries()) {
        if (key.startsWith('otp_') && data.hash) {
          stats.totalOTPs++;
          
          if (now <= data.expiresAt && !data.used) {
            stats.activeOTPs++;
          } else if (data.used) {
            stats.usedOTPs++;
          } else if (now > data.expiresAt) {
            stats.expiredOTPs++;
          }

          if (data.phone) {
            stats.otpsByPhone[data.phone] = (stats.otpsByPhone[data.phone] || 0) + 1;
          }

          totalAttempts += data.attempts;
          otpCount++;
        }

        if (key.startsWith('otp_gen:') && data.suspiciousPatterns) {
          stats.suspiciousActivities += data.suspiciousPatterns.length;
        }
      }

      if (otpCount > 0) {
        stats.averageAttempts = totalAttempts / otpCount;
      }

      return stats;
    } catch (error) {
      logger.error('otp_security_stats_error', { error: error.message });
      return {
        totalOTPs: 0,
        activeOTPs: 0,
        usedOTPs: 0,
        expiredOTPs: 0,
        otpsByPhone: {},
        averageAttempts: 0,
        suspiciousActivities: 0
      };
    }
  }

  /**
   * Check if phone number is temporarily blocked
   */
  isPhoneBlocked(phone) {
    try {
      const normalizedPhone = this.normalizePhone(phone);
      const key = `otp_rate:${normalizedPhone}`;
      const rateData = this.otpAttempts.get(key);
      
      if (!rateData || !rateData.blockedUntil) {
        return false;
      }

      return Date.now() < rateData.blockedUntil;
    } catch (error) {
      logger.error('phone_block_check_error', { error: error.message });
      return false;
    }
  }

  /**
   * Get remaining block time for phone
   */
  getPhoneBlockRemainingTime(phone) {
    try {
      const normalizedPhone = this.normalizePhone(phone);
      const key = `otp_rate:${normalizedPhone}`;
      const rateData = this.otpAttempts.get(key);
      
      if (!rateData || !rateData.blockedUntil) {
        return 0;
      }

      const remaining = rateData.blockedUntil - Date.now();
      return Math.max(0, Math.ceil(remaining / 1000));
    } catch (error) {
      logger.error('phone_block_time_error', { error: error.message });
      return 0;
    }
  }
}

module.exports = new OTPSecurity();
