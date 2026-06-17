const speakeasy = require('speakeasy');
const qrcode = require('qrcode');
const { query } = require('../../db/postgres');
const { logger } = require('../../utils/logger');
const { sentry } = require('../../utils/sentry');
const { encryptMfaSecret, decryptMfaSecret, isEncrypted } = require('../../utils/mfaEncryption');

class MFAService {
  constructor() {
    this.backupCodes = new Map(); // In production, use Redis or database
  }

  /**
   * Generate a new TOTP secret for a user
   */
  generateSecret(user) {
    try {
      const secret = speakeasy.generateSecret({
        name: `Meatvo (${user.email})`,
        issuer: 'Meatvo',
        length: 32
      });

      logger.info('mfa_secret_generated', { 
        userId: user.id, 
        email: user.email 
      });

      return {
        secret: secret.base32,
        otpauth_url: secret.otpauth_url,
        manual_entry_key: secret.base32
      };
    } catch (error) {
      logger.error('mfa_secret_generation_failed', { 
        error: error.message,
        userId: user.id 
      });
      sentry.captureException(error, { userId: user.id });
      throw new Error('Failed to generate MFA secret');
    }
  }

  /**
   * Generate QR code for the TOTP secret
   */
  async generateQRCode(otpauthUrl) {
    try {
      const qrCodeDataUrl = await qrcode.toDataURL(otpauthUrl, {
        errorCorrectionLevel: 'M',
        type: 'image/png',
        quality: 0.92,
        margin: 1,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      });

      return qrCodeDataUrl;
    } catch (error) {
      logger.error('mfa_qr_generation_failed', { 
        error: error.message 
      });
      sentry.captureException(error);
      throw new Error('Failed to generate QR code');
    }
  }

  /**
   * Verify a TOTP token
   */
  verifyToken(token, secret, window = 1) {
    try {
      const verified = speakeasy.totp.verify({
        secret,
        encoding: 'base32',
        token,
        window, // Allow 1 window before and after (30 seconds each)
        time: Math.floor(Date.now() / 1000)
      });

      logger.info('mfa_token_verification', { 
        verified,
        tokenLength: token ? token.length : 0 
      });

      return verified;
    } catch (error) {
      logger.error('mfa_token_verification_failed', { 
        error: error.message 
      });
      sentry.captureException(error);
      return false;
    }
  }

  /**
   * Generate backup codes for a user
   */
  generateBackupCodes(userId, count = 10) {
    try {
      const codes = [];
      const hashedCodes = [];

      for (let i = 0; i < count; i++) {
        const code = this.generateRandomCode();
        const hashedCode = this.hashBackupCode(code);
        
        codes.push(code);
        hashedCodes.push(hashedCode);
      }

      // Store hashed codes (in production, use database)
      this.backupCodes.set(userId, hashedCodes);

      logger.info('mfa_backup_codes_generated', { 
        userId,
        codeCount: count 
      });

      return codes;
    } catch (error) {
      logger.error('mfa_backup_codes_generation_failed', { 
        error: error.message,
        userId 
      });
      sentry.captureException(error, { userId });
      throw new Error('Failed to generate backup codes');
    }
  }

  /**
   * Verify a backup code
   */
  verifyBackupCode(userId, code) {
    try {
      const hashedCodes = this.backupCodes.get(userId) || [];
      const hashedInput = this.hashBackupCode(code);

      const codeIndex = hashedCodes.findIndex(hashedCode => 
        this.safeCompare(hashedCode, hashedInput)
      );

      if (codeIndex === -1) {
        logger.warn('mfa_backup_code_invalid', { userId });
        return false;
      }

      // Remove the used backup code
      hashedCodes.splice(codeIndex, 1);
      this.backupCodes.set(userId, hashedCodes);

      logger.info('mfa_backup_code_used', { 
        userId,
        remainingCodes: hashedCodes.length 
      });

      return true;
    } catch (error) {
      logger.error('mfa_backup_code_verification_failed', { 
        error: error.message,
        userId 
      });
      sentry.captureException(error, { userId });
      return false;
    }
  }

  /**
   * Generate a random backup code
   */
  generateRandomCode() {
    const crypto = require('crypto');
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';

    for (let i = 0; i < 8; i++) {
      if (i > 0 && i % 4 === 0) {
        code += '-';
      }
      code += chars.charAt(crypto.randomInt(chars.length));
    }

    return code;
  }

  /**
   * Hash a backup code for storage
   */
  hashBackupCode(code) {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(code).digest('hex');
  }

  /**
   * Safe string comparison to prevent timing attacks
   */
  safeCompare(a, b) {
    if (a.length !== b.length) {
      return false;
    }

    let result = 0;
    for (let i = 0; i < a.length; i++) {
      result |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }

    return result === 0;
  }

  /**
   * Check if user has MFA enabled
   */
  isMFAEnabled(user) {
    return Boolean(user.mfaEnabled || user.mfa_enabled) && Boolean(user.mfaSecret || user.mfa_secret);
  }

  resolveStoredSecret(stored) {
    return decryptMfaSecret(stored);
  }

  /**
   * Enable MFA for a user
   */
  async enableMFA(userId, secret, backupCodes) {
    try {
      const hashedBackupCodes =
        this.backupCodes.get(userId) || (backupCodes || []).map((code) => this.hashBackupCode(code));

      const encryptedSecret = encryptMfaSecret(secret);
      await query(
        `UPDATE users
         SET mfa_enabled = TRUE,
             mfa_secret = $2,
             mfa_backup_codes = $3::jsonb
         WHERE id = $1`,
        [userId, encryptedSecret, JSON.stringify(hashedBackupCodes)]
      );

      logger.info('mfa_enabled', { userId });
      return true;
    } catch (error) {
      logger.error('mfa_enabling_failed', { 
        error: error.message,
        userId 
      });
      sentry.captureException(error, { userId });
      throw new Error('Failed to enable MFA');
    }
  }

  /**
   * Disable MFA for a user
   */
  async disableMFA(userId) {
    try {
      await query(
        `UPDATE users
         SET mfa_enabled = FALSE,
             mfa_secret = NULL,
             mfa_backup_codes = NULL
         WHERE id = $1`,
        [userId]
      );

      // Clear backup codes from memory
      this.backupCodes.delete(userId);

      logger.info('mfa_disabled', { userId });
      return true;
    } catch (error) {
      logger.error('mfa_disabling_failed', { 
        error: error.message,
        userId 
      });
      sentry.captureException(error, { userId });
      throw new Error('Failed to disable MFA');
    }
  }

  /**
   * Get remaining backup codes count
   */
  getRemainingBackupCodes(userId) {
    const codes = this.backupCodes.get(userId) || [];
    return codes.length;
  }

  /**
   * Regenerate backup codes
   */
  regenerateBackupCodes(userId) {
    try {
      const codes = this.generateBackupCodes(userId);
      logger.info('mfa_backup_codes_regenerated', { 
        userId,
        codeCount: codes.length 
      });
      return codes;
    } catch (error) {
      logger.error('mfa_backup_codes_regeneration_failed', { 
        error: error.message,
        userId 
      });
      sentry.captureException(error, { userId });
      throw new Error('Failed to regenerate backup codes');
    }
  }

  /**
   * Validate MFA setup (verify first token)
   */
  validateSetup(secret, token) {
    try {
      const isValid = this.verifyToken(token, secret, 0); // No window for setup
      
      if (isValid) {
        logger.info('mfa_setup_validated', { 
          tokenLength: token ? token.length : 0 
        });
      } else {
        logger.warn('mfa_setup_validation_failed', { 
          tokenLength: token ? token.length : 0 
        });
      }

      return isValid;
    } catch (error) {
      logger.error('mfa_setup_validation_error', { 
        error: error.message 
      });
      sentry.captureException(error);
      return false;
    }
  }

  /**
   * Get MFA status for user
   */
  getMFAStatus(user) {
    return {
      enabled: this.isMFAEnabled(user),
      hasBackupCodes: this.getRemainingBackupCodes(user.id) > 0,
      backupCodesCount: this.getRemainingBackupCodes(user.id)
    };
  }

  async getUserMFA(userId) {
    const { rows } = await query(
      `SELECT id,
              mfa_enabled AS "mfaEnabled",
              mfa_secret AS "mfaSecret",
              mfa_backup_codes AS "mfaBackupCodes"
       FROM users
       WHERE id = $1`,
      [userId]
    );
    const user = rows[0];
    if (user?.mfaSecret) {
      const rawStored = user.mfaSecret;
      user.mfaSecret = decryptMfaSecret(rawStored);
      if (!isEncrypted(rawStored) && user.mfaSecret) {
        try {
          await query('UPDATE users SET mfa_secret = $1 WHERE id = $2', [
            encryptMfaSecret(user.mfaSecret),
            userId,
          ]);
        } catch (reencryptErr) {
          logger.warn('mfa_secret_reencrypt_failed', { userId, message: reencryptErr.message });
        }
      }
    }
    return user || null;
  }

  /**
   * Generate MFA response with QR code
   */
  async generateMFAResponse(user) {
    try {
      const { secret, otpauth_url } = this.generateSecret(user);
      const qrCode = await this.generateQRCode(otpauth_url);
      const backupCodes = this.generateBackupCodes(user.id);

      return {
        secret,
        qrCode,
        backupCodes,
        manualEntryKey: secret,
        instructions: {
          step1: 'Scan the QR code with your authenticator app',
          step2: 'Enter the 6-digit code to verify setup',
          step3: 'Save the backup codes in a secure location'
        }
      };
    } catch (error) {
      logger.error('mfa_response_generation_failed', { 
        error: error.message,
        userId: user.id 
      });
      sentry.captureException(error, { userId: user.id });
      throw new Error('Failed to generate MFA setup');
    }
  }
}

module.exports = new MFAService();
