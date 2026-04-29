const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class AccountLockoutService {
  constructor() {
    this.lockedAccounts = new Map(); // In production, use Redis
    this.failedAttempts = new Map(); // In production, use Redis
    this.lockoutDuration = 15 * 60 * 1000; // 15 minutes
    this.maxFailedAttempts = 5;
    this.failedAttemptWindow = 15 * 60 * 1000; // 15 minutes
    this.incrementalLockout = true; // Progressive lockout
  }

  /**
   * Record failed login attempt
   */
  recordFailedAttempt(identifier, type = 'phone') {
    try {
      const key = `${type}:${identifier}`;
      const now = Date.now();
      
      let attempts = this.failedAttempts.get(key) || {
        count: 0,
        attempts: [],
        lockoutLevel: 0
      };

      // Clean up old attempts
      attempts.attempts = attempts.attempts.filter(
        timestamp => now - timestamp < this.failedAttemptWindow
      );

      // Add new attempt
      attempts.attempts.push(now);
      attempts.count = attempts.attempts.length;

      this.failedAttempts.set(key, attempts);

      logger.warn('failed_login_attempt_recorded', {
        type,
        identifier: this.maskIdentifier(identifier, type),
        attemptsCount: attempts.count,
        maxAttempts: this.maxFailedAttempts
      });

      sentry.addBreadcrumb({
        message: 'Failed login attempt recorded',
        category: 'auth',
        level: 'warning',
        data: {
          type,
          identifier: this.maskIdentifier(identifier, type),
          attemptsCount: attempts.count
        }
      });

      // Check if account should be locked
      if (attempts.count >= this.maxFailedAttempts) {
        return this.lockAccount(identifier, type, attempts);
      }

      return { locked: false, attemptsRemaining: this.maxFailedAttempts - attempts.count };
    } catch (error) {
      logger.error('failed_attempt_recording_error', { error: error.message });
      sentry.captureException(error);
      return { locked: false, attemptsRemaining: this.maxFailedAttempts };
    }
  }

  /**
   * Lock account due to failed attempts
   */
  lockAccount(identifier, type, attempts) {
    try {
      const key = `${type}:${identifier}`;
      const lockoutLevel = this.incrementalLockout ? attempts.lockoutLevel + 1 : 1;
      
      // Calculate lockout duration (progressive)
      const lockoutDuration = this.incrementalLockout 
        ? this.lockoutDuration * Math.pow(2, lockoutLevel - 1)
        : this.lockoutDuration;

      const lockoutData = {
        identifier,
        type,
        lockedAt: Date.now(),
        expiresAt: Date.now() + lockoutDuration,
        lockoutLevel,
        reason: 'too_many_failed_attempts',
        failedAttemptsCount: attempts.count,
        lockoutDuration
      };

      this.lockedAccounts.set(key, lockoutData);
      attempts.lockoutLevel = lockoutLevel;
      this.failedAttempts.set(key, attempts);

      logger.warn('account_locked', {
        type,
        identifier: this.maskIdentifier(identifier, type),
        lockoutLevel,
        lockoutDuration,
        expiresAt: lockoutData.expiresAt,
        failedAttemptsCount: attempts.count
      });

      sentry.addBreadcrumb({
        message: 'Account locked due to failed attempts',
        category: 'auth',
        level: 'error',
        data: {
          type,
          identifier: this.maskIdentifier(identifier, type),
          lockoutLevel,
          lockoutDuration,
          failedAttemptsCount: attempts.count
        }
      });

      return {
        locked: true,
        lockoutLevel,
        lockoutDuration,
        expiresAt: lockoutData.expiresAt,
        attemptsRemaining: 0
      };
    } catch (error) {
      logger.error('account_lockout_error', { error: error.message });
      sentry.captureException(error);
      return { locked: false, error: 'Lockout failed' };
    }
  }

  /**
   * Check if account is locked
   */
  isAccountLocked(identifier, type) {
    try {
      const key = `${type}:${identifier}`;
      const lockoutData = this.lockedAccounts.get(key);

      if (!lockoutData) {
        return { locked: false };
      }

      // Check if lockout has expired
      if (Date.now() > lockoutData.expiresAt) {
        this.unlockAccount(identifier, type);
        return { locked: false };
      }

      const remainingTime = Math.ceil((lockoutData.expiresAt - Date.now()) / 1000);

      return {
        locked: true,
        lockoutLevel: lockoutData.lockoutLevel,
        expiresAt: lockoutData.expiresAt,
        remainingTime,
        reason: lockoutData.reason
      };
    } catch (error) {
      logger.error('account_lockout_check_error', { error: error.message });
      return { locked: false, error: 'Lockout check failed' };
    }
  }

  /**
   * Unlock account
   */
  unlockAccount(identifier, type, reason = 'automatic') {
    try {
      const key = `${type}:${identifier}`;
      const lockoutData = this.lockedAccounts.get(key);

      if (lockoutData) {
        this.lockedAccounts.delete(key);

        // Reset failed attempts count
        const attempts = this.failedAttempts.get(key);
        if (attempts) {
          attempts.count = 0;
          attempts.attempts = [];
          attempts.lockoutLevel = 0;
          this.failedAttempts.set(key, attempts);
        }

        logger.info('account_unlocked', {
          type,
          identifier: this.maskIdentifier(identifier, type),
          reason,
          previouslyLockedAt: lockoutData.lockedAt
        });

        sentry.addBreadcrumb({
          message: 'Account unlocked',
          category: 'auth',
          level: 'info',
          data: {
            type,
            identifier: this.maskIdentifier(identifier, type),
            reason
          }
        });
      }

      return true;
    } catch (error) {
      logger.error('account_unlock_error', { error: error.message });
      return false;
    }
  }

  /**
   * Clear failed attempts on successful login
   */
  clearFailedAttempts(identifier, type) {
    try {
      const key = `${type}:${identifier}`;
      this.failedAttempts.delete(key);

      logger.info('failed_attempts_cleared', {
        type,
        identifier: this.maskIdentifier(identifier, type)
      });

      return true;
    } catch (error) {
      logger.error('failed_attempts_clear_error', { error: error.message });
      return false;
    }
  }

  /**
   * Manually lock account (admin function)
   */
  manualLockAccount(identifier, type, reason = 'admin_action', duration = null) {
    try {
      const key = `${type}:${identifier}`;
      const lockoutDuration = duration || this.lockoutDuration;

      const lockoutData = {
        identifier,
        type,
        lockedAt: Date.now(),
        expiresAt: Date.now() + lockoutDuration,
        lockoutLevel: 1,
        reason,
        manual: true,
        lockoutDuration
      };

      this.lockedAccounts.set(key, lockoutData);

      logger.warn('account_manually_locked', {
        type,
        identifier: this.maskIdentifier(identifier, type),
        reason,
        lockoutDuration,
        expiresAt: lockoutData.expiresAt
      });

      return {
        locked: true,
        expiresAt: lockoutData.expiresAt,
        lockoutDuration
      };
    } catch (error) {
      logger.error('manual_account_lock_error', { error: error.message });
      return { locked: false, error: 'Manual lock failed' };
    }
  }

  /**
   * Get account lockout statistics
   */
  getLockoutStats() {
    try {
      const stats = {
        totalLockedAccounts: this.lockedAccounts.size,
        lockedAccountsByType: {},
        lockedAccountsByLevel: {},
        totalFailedAttempts: 0,
        failedAttemptsByType: {},
        averageLockoutDuration: 0
      };

      let totalLockoutDuration = 0;
      let lockoutCount = 0;

      // Count locked accounts
      for (const [key, lockoutData] of this.lockedAccounts.entries()) {
        const type = lockoutData.type;
        const level = lockoutData.lockoutLevel;

        stats.lockedAccountsByType[type] = (stats.lockedAccountsByType[type] || 0) + 1;
        stats.lockedAccountsByLevel[level] = (stats.lockedAccountsByLevel[level] || 0) + 1;

        totalLockoutDuration += lockoutData.lockoutDuration;
        lockoutCount++;
      }

      // Count failed attempts
      for (const [key, attempts] of this.failedAttempts.entries()) {
        const type = key.split(':')[0];
        
        stats.totalFailedAttempts += attempts.count;
        stats.failedAttemptsByType[type] = (stats.failedAttemptsByType[type] || 0) + attempts.count;
      }

      if (lockoutCount > 0) {
        stats.averageLockoutDuration = totalLockoutDuration / lockoutCount;
      }

      return stats;
    } catch (error) {
      logger.error('lockout_stats_error', { error: error.message });
      return {
        totalLockedAccounts: 0,
        lockedAccountsByType: {},
        lockedAccountsByLevel: {},
        totalFailedAttempts: 0,
        failedAttemptsByType: {},
        averageLockoutDuration: 0
      };
    }
  }

  /**
   * Clean up expired lockouts and attempts
   */
  cleanupExpiredData() {
    try {
      const now = Date.now();
      let cleanedLockouts = 0;
      let cleanedAttempts = 0;

      // Clean up expired lockouts
      for (const [key, lockoutData] of this.lockedAccounts.entries()) {
        if (now > lockoutData.expiresAt) {
          this.unlockAccount(lockoutData.identifier, lockoutData.type, 'expired');
          cleanedLockouts++;
        }
      }

      // Clean up expired failed attempts
      for (const [key, attempts] of this.failedAttempts.entries()) {
        attempts.attempts = attempts.attempts.filter(
          timestamp => now - timestamp < this.failedAttemptWindow
        );

        if (attempts.attempts.length === 0) {
          this.failedAttempts.delete(key);
          cleanedAttempts++;
        } else {
          attempts.count = attempts.attempts.length;
          this.failedAttempts.set(key, attempts);
        }
      }

      if (cleanedLockouts > 0 || cleanedAttempts > 0) {
        logger.info('account_lockout_cleanup', {
          cleanedLockouts,
          cleanedAttempts
        });
      }
    } catch (error) {
      logger.error('account_lockout_cleanup_error', { error: error.message });
    }
  }

  /**
   * Mask sensitive identifiers for logging
   */
  maskIdentifier(identifier, type) {
    if (!identifier || typeof identifier !== 'string') {
      return identifier;
    }

    if (type === 'phone') {
      const normalized = identifier.replace(/\D/g, '');
      if (normalized.length >= 10) {
        return normalized.substring(0, 3) + '******' + normalized.substring(normalized.length - 2);
      }
    } else if (type === 'email') {
      const [username, domain] = identifier.split('@');
      if (username && domain) {
        return username.substring(0, 2) + '***@' + domain;
      }
    }

    return identifier.substring(0, 3) + '******';
  }

  /**
   * Get lockout configuration
   */
  getConfiguration() {
    return {
      maxFailedAttempts: this.maxFailedAttempts,
      lockoutDuration: this.lockoutDuration,
      failedAttemptWindow: this.failedAttemptWindow,
      incrementalLockout: this.incrementalLockout
    };
  }

  /**
   * Update lockout configuration
   */
  updateConfiguration(config) {
    try {
      if (config.maxFailedAttempts !== undefined) {
        this.maxFailedAttempts = config.maxFailedAttempts;
      }
      
      if (config.lockoutDuration !== undefined) {
        this.lockoutDuration = config.lockoutDuration;
      }
      
      if (config.failedAttemptWindow !== undefined) {
        this.failedAttemptWindow = config.failedAttemptWindow;
      }
      
      if (config.incrementalLockout !== undefined) {
        this.incrementalLockout = config.incrementalLockout;
      }

      logger.info('account_lockout_config_updated', { config });
    } catch (error) {
      logger.error('account_lockout_config_update_error', { error: error.message });
    }
  }
}

module.exports = new AccountLockoutService();
