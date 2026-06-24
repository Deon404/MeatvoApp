const {
  REQUIRED_ALWAYS,
  REQUIRED_PRODUCTION,
  OTP_SMS_REQUIRED,
  DEFAULTS,
} = require('./env.constants');

// SECURITY FIX: reject known committed dev-default secrets in all environments
const KNOWN_DEV_SECRETS = new Set([
  'dev-access-secret-change-me',
  'dev-refresh-secret-change-me',
  'dev-otp-hash-secret-change-me',
  'dev_access_secret_change_me',
  'dev_refresh_secret_change_me',
  'dev_otp_hash_secret_change_me',
  'dev_login_secret',
  'StrongDbPass!',
  'StrongRedisPass!',
  '123400',
  '786404',
]);

const ALWAYS_REQUIRED_SECRETS = [
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'OTP_HASH_SECRET',
];

const WEAK_SECRET_PATTERNS = [
  /^CHANGE_ME$/i,
  /change.?me/i,
  /your_.*_(here|key|secret|password)/i,
  /^placeholder$/i,
  /placeholder@/i,
  /^password$/i,
  /^secret$/i,
  /^test$/i,
  /^12345678$/,
];

const MIN_SECRET_LENGTH = 32;

const SECRET_KEYS = [
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'JWT_SECRET',
  'OTP_HASH_SECRET',
  'MFA_ENCRYPTION_KEY',
  'UPLOAD_SIGNING_SECRET',
  'DB_PASSWORD',
  'CASHFREE_SECRET_KEY',
  'DEV_AUTH_BYPASS_SECRET',
];

function isKnownDevSecret(value) {
  if (value == null) return false;
  return KNOWN_DEV_SECRETS.has(String(value).trim());
}

function isWeakSecret(value, { requireMinLength = true } = {}) {
  if (!value || typeof value !== 'string') return true;
  const trimmed = value.trim();
  if (requireMinLength && trimmed.length < MIN_SECRET_LENGTH) return true;
  return WEAK_SECRET_PATTERNS.some((pattern) => pattern.test(trimmed));
}

function isWeakSecretForKey(key, value) {
  const isProduction = process.env.NODE_ENV === 'production';
  const requireMinLength = isProduction || key !== 'DB_PASSWORD';
  return isWeakSecret(value, { requireMinLength });
}

function validateSecretsAlways() {
  const errors = [];

  for (const key of ALWAYS_REQUIRED_SECRETS) {
    const value = process.env[key];
    if (!value || !String(value).trim()) {
      errors.push(`${key} is required and must not be empty`);
      continue;
    }
    if (isKnownDevSecret(value)) {
      errors.push(`${key} matches a known dev-default — rotate before deploy`);
      continue;
    }
    if (isWeakSecretForKey(key, value)) {
      errors.push(`${key} is too weak (min ${MIN_SECRET_LENGTH} chars, no placeholders)`);
    }
  }

  for (const key of SECRET_KEYS) {
    if (ALWAYS_REQUIRED_SECRETS.includes(key)) continue;
    const value = process.env[key];
    if (value === undefined || value === null || value === '') continue;
    const trimmed = String(value).trim();
    if (!trimmed) {
      errors.push(`${key} must not be whitespace-only when set`);
      continue;
    }
    if (isKnownDevSecret(trimmed)) {
      errors.push(`${key} matches a known dev-default — rotate before deploy`);
      continue;
    }
    if (isWeakSecretForKey(key, trimmed)) {
      errors.push(`${key} is too weak (min ${MIN_SECRET_LENGTH} chars, no placeholders)`);
    }
  }

  if (!process.env.JWT_ACCESS_SECRET && !process.env.JWT_REFRESH_SECRET && process.env.JWT_SECRET) {
    const legacy = process.env.JWT_SECRET;
    if (isKnownDevSecret(legacy)) {
      errors.push('JWT_SECRET matches a known dev-default — rotate before deploy');
    } else if (isWeakSecretForKey('JWT_SECRET', legacy)) {
      errors.push('JWT_SECRET is too weak for production');
    }
  }

  return errors;
}

function validateCashfreeEnv() {
  const errors = [];
  const env = String(process.env.CASHFREE_ENV || '').trim().toLowerCase();

  if (!env) {
    errors.push('CASHFREE_ENV is required and must be "sandbox" or "production"');
    return errors;
  }

  if (env !== 'sandbox' && env !== 'production') {
    errors.push('CASHFREE_ENV must be "sandbox" or "production"');
    return errors;
  }

  const isProduction = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
  if (isProduction && env !== 'production') {
    errors.push('CASHFREE_ENV must be "production" when NODE_ENV=production');
  }

  const legacyApiBase = String(process.env.CASHFREE_API_BASE || '').toLowerCase();
  if (legacyApiBase) {
    const legacyIsSandbox = legacyApiBase.includes('sandbox');
    const legacyIsProduction = legacyApiBase.includes('api.cashfree.com');
    if (env === 'production' && legacyIsSandbox) {
      errors.push('CASHFREE_API_BASE points to sandbox but CASHFREE_ENV=production');
    }
    if (env === 'sandbox' && legacyIsProduction) {
      errors.push('CASHFREE_API_BASE points to production but CASHFREE_ENV=sandbox');
    }
  }

  return errors;
}

function validateProductionSecurity() {
  const errors = [];

  if (String(process.env.DISABLE_API_RATE_LIMIT || '').toLowerCase() === 'true') {
    errors.push('DISABLE_API_RATE_LIMIT must not be true in production');
  }

  if (String(process.env.DEV_AUTH_BYPASS_ENABLED || '').toLowerCase() === 'true') {
    errors.push('DEV_AUTH_BYPASS_ENABLED must be false in production');
  }

  if (String(process.env.OTP_LOG_TO_CONSOLE || '').toLowerCase() === 'true') {
    errors.push('OTP_LOG_TO_CONSOLE must be false in production');
  }

  if (String(process.env.REDIS_ALLOW_FALLBACK || '').toLowerCase() === 'true') {
    errors.push('REDIS_ALLOW_FALLBACK must not be true in production');
  }

  const sentryDsn = process.env.SENTRY_DSN || '';
  if (!sentryDsn || /placeholder|o0\.ingest\.sentry\.io\/0/i.test(sentryDsn)) {
    errors.push('SENTRY_DSN must be a real Sentry project DSN (not a placeholder)');
  }

  const corsOrigins = process.env.CORS_ORIGINS || '';
  if (!corsOrigins || /YOUR_DOMAIN/i.test(corsOrigins)) {
    errors.push('CORS_ORIGINS must list your real HTTPS domain(s)');
  }

  for (const key of ['DATABASE_URL', 'REDIS_URL']) {
    const value = process.env[key] || '';
    if (/CHANGE_ME/i.test(value)) {
      errors.push(`${key} still contains CHANGE_ME — replace with real credentials`);
    }
  }

  for (const key of SECRET_KEYS) {
    const value = process.env[key];
    if (!value) continue;
    if (isKnownDevSecret(value)) {
      errors.push(`${key} matches a known dev-default — rotate before deploy`);
      continue;
    }
    if (isWeakSecret(value)) {
      errors.push(`${key} is missing or too weak (min ${MIN_SECRET_LENGTH} chars, no placeholders)`);
    }
  }

  if (!process.env.JWT_ACCESS_SECRET && !process.env.JWT_REFRESH_SECRET && process.env.JWT_SECRET) {
    if (isKnownDevSecret(process.env.JWT_SECRET)) {
      errors.push('JWT_SECRET matches a known dev-default — rotate before deploy');
    } else if (isWeakSecret(process.env.JWT_SECRET)) {
      errors.push('JWT_SECRET is too weak for production');
    }
  }

  const cashfreeEnvErrors = validateCashfreeEnv();
  for (const err of cashfreeEnvErrors) {
    errors.push(err);
  }

  return errors;
}

function validateEnv() {
  const isProduction = process.env.NODE_ENV === 'production';

  // SECURITY FIX: fail startup in all environments if secrets missing, weak, or dev-default
  const secretErrors = validateSecretsAlways();
  if (secretErrors.length > 0) {
    console.error('Secret validation failed:');
    for (const err of secretErrors) {
      console.error(`  - ${err}`);
    }
    process.exit(1);
  }

  const hasJwtSecretPair = Boolean(process.env.JWT_ACCESS_SECRET && process.env.JWT_REFRESH_SECRET);
  const hasLegacyJwtSecret = Boolean(process.env.JWT_SECRET);
  const hasJwtConfig = hasJwtSecretPair || hasLegacyJwtSecret;

  const list = isProduction ? REQUIRED_PRODUCTION : REQUIRED_ALWAYS;

  const missing = list.filter((key) => !process.env[key]);
  if (!hasJwtConfig) {
    missing.unshift('JWT_ACCESS_SECRET/JWT_REFRESH_SECRET (or legacy JWT_SECRET)');
  }

  const smsProvider = (process.env.SMS_PROVIDER || DEFAULTS.SMS_PROVIDER).trim().toLowerCase();
  if (smsProvider === 'msg91' || smsProvider === '') {
    const otpMissing = OTP_SMS_REQUIRED.filter((key) => !process.env[key]);
    if (!process.env.MSG91_OTP_TEMPLATE_ID && !process.env.MSG91_TEMPLATE_ID) {
      otpMissing.push('MSG91_OTP_TEMPLATE_ID or MSG91_TEMPLATE_ID');
    }
    for (const key of otpMissing) {
      if (!missing.includes(key)) missing.push(key);
    }
  }

  if (missing.length > 0) {
    console.error('Missing required env vars:', missing.join(', '));
    // SECURITY FIX: fail in all environments, not only production
    process.exit(1);
  }

  const cashfreeEnvErrors = validateCashfreeEnv();
  if (cashfreeEnvErrors.length > 0) {
    console.error('Cashfree env validation failed:');
    for (const err of cashfreeEnvErrors) {
      console.error(`  - ${err}`);
    }
    process.exit(1);
  }

  if (process.env.FIREBASE_API_KEY && !process.env.FIREBASE_VAPID_KEY) {
    const msg = 'FIREBASE_VAPID_KEY is required when FIREBASE_API_KEY is set (admin web push)';
    if (isProduction) {
      console.error(msg);
      process.exit(1);
    }
    console.warn(msg);
  }

  if (isProduction) {
    const securityErrors = validateProductionSecurity();
    if (securityErrors.length > 0) {
      console.error('Production security validation failed:');
      for (const err of securityErrors) {
        console.error(`  - ${err}`);
      }
      process.exit(1);
    }
    console.log('Production env validation passed.');
  }
}

module.exports = {
  validateEnv,
  validateProductionSecurity,
  validateSecretsAlways,
  validateCashfreeEnv,
  isWeakSecret,
  isKnownDevSecret,
  KNOWN_DEV_SECRETS,
};
