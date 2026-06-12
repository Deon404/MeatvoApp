const {
  REQUIRED_ALWAYS,
  REQUIRED_PRODUCTION,
  OTP_SMS_REQUIRED,
  PAYMENT_REQUIRED,
  NUMERIC_BOUNDS,
  DEFAULTS,
} = require('./env.constants');

const DEV_REQUIRED = REQUIRED_ALWAYS.slice(0, 6);

function validateEnv() {
  const hasJwtSecretPair = Boolean(process.env.JWT_ACCESS_SECRET && process.env.JWT_REFRESH_SECRET);
  const hasLegacyJwtSecret = Boolean(process.env.JWT_SECRET);
  const hasJwtConfig = hasJwtSecretPair || hasLegacyJwtSecret;

  const list = process.env.NODE_ENV === 'production'
    ? REQUIRED_PRODUCTION
    : DEV_REQUIRED;

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
    if (process.env.NODE_ENV === 'production') process.exit(1);
    else console.warn('Running in dev mode without some env vars');
  }

  if (process.env.FIREBASE_API_KEY && !process.env.FIREBASE_VAPID_KEY) {
    const msg = 'FIREBASE_VAPID_KEY is required when FIREBASE_API_KEY is set (admin web push)';
    if (process.env.NODE_ENV === 'production') {
      console.error(msg);
      process.exit(1);
    }
    console.warn(msg);
  }
}

module.exports = { validateEnv };
