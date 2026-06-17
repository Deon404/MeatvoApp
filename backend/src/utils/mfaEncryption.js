const crypto = require('crypto');
const { logger } = require('./logger');

const PREFIX = 'mfaenc:v1:';
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const KEY_SALT = 'meatvo-mfa-encryption-v1';

const getEncryptionKey = () => {
  const secret = process.env.MFA_ENCRYPTION_KEY || process.env.OTP_HASH_SECRET;
  if (!secret) {
    throw new Error('MFA_ENCRYPTION_KEY or OTP_HASH_SECRET is required for MFA encryption');
  }
  return crypto.scryptSync(secret, KEY_SALT, 32);
};

const isEncrypted = (value) => typeof value === 'string' && value.startsWith(PREFIX);

const timingSafeEqualStr = (a, b) => {
  const ba = Buffer.from(String(a || ''));
  const bb = Buffer.from(String(b || ''));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

/**
 * Encrypt MFA TOTP secret for database storage (AES-256-GCM).
 */
const encryptMfaSecret = (plaintext) => {
  if (!plaintext) return null;
  if (isEncrypted(plaintext)) return plaintext;

  const key = getEncryptionKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(String(plaintext), 'utf8', 'base64url');
  encrypted += cipher.final('base64url');
  const tag = cipher.getAuthTag().toString('base64url');
  return `${PREFIX}${iv.toString('base64url')}.${encrypted}.${tag}`;
};

/**
 * Decrypt MFA TOTP secret from database.
 * Legacy plaintext values are returned as-is (logged once per process).
 */
const decryptMfaSecret = (stored) => {
  if (!stored) return null;
  const value = String(stored);
  if (!isEncrypted(value)) {
    logger.warn('mfa_secret_plaintext_legacy', { message: 'Plaintext MFA secret detected; will encrypt on next MFA update' });
    return value;
  }

  try {
    const payload = value.slice(PREFIX.length);
    const [ivB64, encB64, tagB64] = payload.split('.');
    if (!ivB64 || !encB64 || !tagB64) return null;

    const key = getEncryptionKey();
    const decipher = crypto.createDecipheriv(ALGORITHM, key, Buffer.from(ivB64, 'base64url'));
    decipher.setAuthTag(Buffer.from(tagB64, 'base64url'));
    let decrypted = decipher.update(encB64, 'base64url', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    logger.error('mfa_secret_decrypt_failed', { message: err.message });
    return null;
  }
};

module.exports = {
  encryptMfaSecret,
  decryptMfaSecret,
  isEncrypted,
  timingSafeEqualStr,
};
