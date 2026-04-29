const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class DeviceService {
  constructor() {
    this.devices = new Map(); // In production, use Redis or database
    this.deviceExpiry = 30 * 24 * 60 * 60 * 1000; // 30 days
  }

  /**
   * Generate device fingerprint
   */
  generateFingerprint(req) {
    try {
      const userAgent = req.get('User-Agent') || '';
      const acceptLanguage = req.get('Accept-Language') || '';
      const acceptEncoding = req.get('Accept-Encoding') || '';
      const ip = req.ip || req.connection.remoteAddress || '';
      
      const fingerprintData = `${userAgent}|${acceptLanguage}|${acceptEncoding}|${ip}`;
      const fingerprint = crypto.createHash('sha256').update(fingerprintData).digest('hex');
      
      return fingerprint;
    } catch (error) {
      logger.error('device_fingerprint_generation_failed', { error: error.message });
      return crypto.randomBytes(32).toString('hex');
    }
  }

  /**
   * Register a new device for a user
   */
  async registerDevice(userId, req) {
    try {
      const fingerprint = this.generateFingerprint(req);
      const deviceId = crypto.randomBytes(16).toString('hex');
      const timestamp = Date.now();
      
      const deviceInfo = {
        id: deviceId,
        userId,
        fingerprint,
        userAgent: req.get('User-Agent') || '',
        ip: req.ip || req.connection.remoteAddress || '',
        firstSeen: timestamp,
        lastSeen: timestamp,
        isActive: true,
        trusted: false
      };

      // Store device (in production, use database)
      this.devices.set(`${userId}:${fingerprint}`, deviceInfo);

      logger.info('device_registered', { 
        userId, 
        deviceId, 
        fingerprint: fingerprint.substring(0, 8) + '...',
        ip: deviceInfo.ip 
      });

      return deviceInfo;
    } catch (error) {
      logger.error('device_registration_failed', { error: error.message, userId });
      sentry.captureException(error, { userId });
      throw new Error('Failed to register device');
    }
  }

  /**
   * Verify device is registered and active
   */
  async verifyDevice(userId, req) {
    try {
      const fingerprint = this.generateFingerprint(req);
      const deviceKey = `${userId}:${fingerprint}`;
      const device = this.devices.get(deviceKey);

      if (!device) {
        logger.warn('device_not_found', { 
          userId, 
          fingerprint: fingerprint.substring(0, 8) + '...' 
        });
        return { valid: false, device: null };
      }

      // Check if device is active
      if (!device.isActive) {
        logger.warn('device_inactive', { 
          userId, 
          deviceId: device.id 
        });
        return { valid: false, device };
      }

      // Check if device has expired
      if (Date.now() - device.lastSeen > this.deviceExpiry) {
        device.isActive = false;
        logger.warn('device_expired', { 
          userId, 
          deviceId: device.id 
        });
        return { valid: false, device };
      }

      // Update last seen
      device.lastSeen = Date.now();
      device.ip = req.ip || req.connection.remoteAddress || '';

      logger.info('device_verified', { 
        userId, 
        deviceId: device.id,
        trusted: device.trusted 
      });

      return { valid: true, device };
    } catch (error) {
      logger.error('device_verification_failed', { error: error.message, userId });
      sentry.captureException(error, { userId });
      return { valid: false, device: null };
    }
  }

  /**
   * Trust a device (skip MFA for trusted devices)
   */
  async trustDevice(userId, deviceId, req) {
    try {
      const fingerprint = this.generateFingerprint(req);
      const deviceKey = `${userId}:${fingerprint}`;
      const device = this.devices.get(deviceKey);

      if (!device || device.id !== deviceId) {
        throw new Error('Device not found');
      }

      device.trusted = true;
      device.trustedAt = Date.now();

      logger.info('device_trusted', { 
        userId, 
        deviceId,
        fingerprint: fingerprint.substring(0, 8) + '...' 
      });

      return device;
    } catch (error) {
      logger.error('device_trust_failed', { error: error.message, userId, deviceId });
      sentry.captureException(error, { userId, deviceId });
      throw new Error('Failed to trust device');
    }
  }

  /**
   * Revoke device access
   */
  async revokeDevice(userId, deviceId) {
    try {
      for (const [key, device] of this.devices.entries()) {
        if (device.userId === userId && device.id === deviceId) {
          device.isActive = false;
          device.revokedAt = Date.now();

          logger.info('device_revoked', { 
            userId, 
            deviceId 
          });
          return device;
        }
      }

      throw new Error('Device not found');
    } catch (error) {
      logger.error('device_revocation_failed', { error: error.message, userId, deviceId });
      sentry.captureException(error, { userId, deviceId });
      throw new Error('Failed to revoke device');
    }
  }

  /**
   * Get all devices for a user
   */
  async getUserDevices(userId) {
    try {
      const userDevices = [];
      
      for (const [key, device] of this.devices.entries()) {
        if (device.userId === userId) {
          userDevices.push({
            id: device.id,
            userAgent: device.userAgent,
            ip: device.ip,
            firstSeen: device.firstSeen,
            lastSeen: device.lastSeen,
            isActive: device.isActive,
            trusted: device.trusted,
            trustedAt: device.trustedAt,
            revokedAt: device.revokedAt
          });
        }
      }

      return userDevices.sort((a, b) => b.lastSeen - a.lastSeen);
    } catch (error) {
      logger.error('get_user_devices_failed', { error: error.message, userId });
      sentry.captureException(error, { userId });
      return [];
    }
  }

  /**
   * Clean up expired devices
   */
  cleanupExpiredDevices() {
    try {
      const now = Date.now();
      for (const [key, device] of this.devices.entries()) {
        if (now - device.lastSeen > this.deviceExpiry) {
          this.devices.delete(key);
        }
      }
    } catch (error) {
      logger.error('device_cleanup_failed', { error: error.message });
    }
  }

  /**
   * Check if user has too many devices
   */
  async hasTooManyDevices(userId, maxDevices = 5) {
    try {
      let deviceCount = 0;
      
      for (const [key, device] of this.devices.entries()) {
        if (device.userId === userId && device.isActive) {
          deviceCount++;
        }
      }

      return deviceCount >= maxDevices;
    } catch (error) {
      logger.error('device_count_check_failed', { error: error.message, userId });
      return false;
    }
  }
}

module.exports = new DeviceService();
