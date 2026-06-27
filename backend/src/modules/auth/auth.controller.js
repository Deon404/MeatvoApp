const asyncHandler = require('express-async-handler');
const crypto = require('crypto');
const redis = require('../../db/redis');
const { query } = require('../../db/postgres');
const { sendOtpSms } = require('../../utils/sms');
const { generateTokens, verifyRefreshToken, sha256 } = require('./auth.service');
const { ROLES } = require('../../utils/roles');
const { fail, ok } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const { sentry } = require('../../utils/sentry');
const mfaService = require('./mfa.service');
const { normalizePhone, normalizeOtp } = require('./auth.validation');

/** Single canonical phone for Redis keys + HMAC (must match between send & verify). */
const otpPhoneKey = (raw) => normalizePhone(raw);

const OTP_TTL_SECONDS = Number(process.env.OTP_TTL_SECONDS || 600);
const OTP_MAX_ATTEMPTS = Number(process.env.OTP_MAX_ATTEMPTS || 3);
const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
// Mobile carriers rotate IPs; default 15 in prod. Set OTP_MAX_UNIQUE_IPS=0 to disable.
const OTP_MAX_UNIQUE_IPS = Number(
  process.env.OTP_MAX_UNIQUE_IPS ?? (isProd ? 15 : 0),
);
const OTP_IP_TRACK_TTL_SECONDS = Number(process.env.OTP_IP_TRACK_TTL_SECONDS || 86400);

const normalizeClientIp = (raw) => {
  const value = String(raw || '').trim();
  if (!value) return 'unknown';
  if (value.startsWith('::ffff:')) return value.slice(7);
  return value;
};
const logOtpToConsole =
  process.env.OTP_LOG_TO_CONSOLE === 'true' && process.env.NODE_ENV !== 'production';

const OTP_LENGTH = Number(process.env.MSG91_OTP_LENGTH || process.env.OTP_LENGTH || 4);

const generateOtpCode = () => {
  const max = 10 ** OTP_LENGTH;
  return String(crypto.randomInt(0, max)).padStart(OTP_LENGTH, '0');
};

const hashOtp = (phone, otp) => {
  const secret = process.env.OTP_HASH_SECRET;
  if (!secret) throw new Error('OTP_HASH_SECRET is required');
  return crypto
    .createHmac('sha256', secret)
    .update(String(phone))
    .update(':')
    .update(String(otp))
    .digest('hex');
};

const roleForNewUser = (phone) => {
  // Admin role is assigned only via the admin panel API — never from env phone lists (SIM-swap risk).
  const deliveryPhones = (process.env.DELIVERY_PHONES || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (deliveryPhones.includes(phone)) return ROLES.DELIVERY;
  return ROLES.CUSTOMER;
};

const timingSafeEqualStr = (a, b) => {
  const sa = String(a || '');
  const sb = String(b || '');
  const ba = Buffer.from(sa);
  const bb = Buffer.from(sb);
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

const maskPhone = (phone) => {
  const value = String(phone || '');
  return value.length > 4 ? `${value.substring(0, 2)}******${value.substring(value.length - 2)}` : '****';
};

const ensureUserForPhone = async (phone) => {
  const existing = await query(
    `SELECT id, phone, name, role,
            mfa_enabled AS "mfaEnabled",
            mfa_secret AS "mfaSecret"
     FROM users
     WHERE phone = $1`,
    [phone]
  );
  let user = existing.rows[0];

  if (!user) {
    const role = roleForNewUser(phone);
    const created = await query(
      `INSERT INTO users (phone, role)
       VALUES ($1, $2)
       RETURNING id, phone, name, role,
                 mfa_enabled AS "mfaEnabled",
                 mfa_secret AS "mfaSecret"`,
      [phone, role]
    );
    user = created.rows[0];
  }
  // Existing users: role comes from DB only (pgAdmin / admin panel).
  // DELIVERY_PHONES applies only when the account is first created.

  if (user.role === ROLES.DELIVERY) {
    await query(
      'INSERT INTO delivery_partners (user_id, is_online) VALUES ($1, FALSE) ON CONFLICT (user_id) DO NOTHING',
      [user.id]
    );
  }

  return user;
};

// POST /api/auth/send-otp
const sendOtp = asyncHandler(async (req, res) => {
  try {
    const phone = otpPhoneKey(req.validated?.body?.phone);

    if (!phone) {
      logger.warn('otp_send_missing_phone', { ip: req.ip });
      return fail(res, 400, 'Phone number is required');
    }

    const maskedPhone = maskPhone(phone);

    // Check blocked phones
    const blockedPhones = (process.env.BLOCKED_PHONES || '')
      .split(',')
      .map(p => p.trim())
      .filter(Boolean);
    
    if (blockedPhones.includes(phone)) {
      logger.warn('otp_send_blocked_phone', { phone: maskedPhone, ip: req.ip });
      return fail(res, 403, 'This phone number is not allowed.');
    }

    // Track IPs per phone (abuse signal). Disabled in dev; threshold configurable in prod.
    if (OTP_MAX_UNIQUE_IPS > 0) {
      const ipTrackKey = `ips:${phone}`;
      const currentIp = normalizeClientIp(req.ip || req.connection?.remoteAddress);
      await redis.sadd(ipTrackKey, currentIp);
      await redis.expire(ipTrackKey, OTP_IP_TRACK_TTL_SECONDS);

      const uniqueIps = await redis.scard(ipTrackKey);
      if (uniqueIps > OTP_MAX_UNIQUE_IPS) {
        logger.warn('suspicious_activity_multiple_ips', {
          phone: maskedPhone,
          uniqueIpCount: uniqueIps,
          maxAllowed: OTP_MAX_UNIQUE_IPS,
          currentIp,
        });
        return fail(res, 429, 'Suspicious activity detected. Contact support.');
      }
    }

    // Check account lockout
    const lockoutKey = `lockout:${phone}`;
    let lockoutCount = 0;
    try {
      lockoutCount = Number(await redis.get(lockoutKey) || 0);
    } catch (e) {
      lockoutCount = 0; // ignore errors
    }
    if (lockoutCount >= 10) {
      logger.warn('otp_send_lockout_active', { phone: maskedPhone, lockoutCount });
      return fail(res, 429, 'Account locked due to too many failed attempts. Try again later.');
    }

    const sendLockKey = `otp:send-lock:${phone}`;
    if (await redis.get(sendLockKey)) {
      return fail(res, 429, 'OTP request already in progress. Please wait a moment.');
    }
    await redis.set(sendLockKey, '1', 'EX', 20);

    // CHECK: Is there already a valid unexpired OTP for this number?
    const existingKey = `otp:${phone}`;
    const forceResend = req.validated?.body?.resend === true;
    if (forceResend) {
      await redis.del(existingKey);
    }
    const existingData = await redis.get(existingKey);
    
    if (existingData) {
      await redis.del(sendLockKey);
      let remainingSeconds = OTP_TTL_SECONDS; // default fallback
      try {
        const parsed = JSON.parse(existingData);
        if (parsed.sentAt) {
          const elapsedSeconds = Math.floor((Date.now() - parsed.sentAt) / 1000);
          remainingSeconds = Math.max(0, OTP_TTL_SECONDS - elapsedSeconds);
        }
      } catch (e) {}
      
      return fail(res, 429, 'OTP already sent. Use existing OTP.', {
        remainingSeconds,
        canResendAt: Date.now() + (remainingSeconds * 1000),
      });
    }
    
    // No existing OTP → proceed to generate new one
    const otp = generateOtpCode();
    const otpHash = hashOtp(phone, otp);
    const redisKey = `otp:${phone}`;

    await redis.set(
      redisKey,
      JSON.stringify({ otpHash, attempts: 0, sentAt: Date.now() }),
      'EX',
      OTP_TTL_SECONDS
    );

    const phoneHash = sha256(phone);
    const templateId = process.env.MSG91_OTP_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID || null;

    let smsResult;
    try {
      smsResult = await sendOtpSms({ phone, otp });
    } catch (smsError) {
      await redis.del(sendLockKey);
      await redis.del(redisKey);
      const isZeroBalance = /wallet balance is zero|balance too low/i.test(smsError.message || '');
      logger.error('otp_send_sms_failed', {
        phone: maskedPhone,
        error: smsError.message,
        httpStatus: smsError.httpStatus,
        msg91: smsError.msg91,
        zeroBalance: isZeroBalance,
      });
      const isTemplateError = /template|dlt|211|400/i.test(smsError.message || '');
      if (isZeroBalance) {
        return fail(res, 503, 'SMS service is temporarily unavailable. Please try again later.');
      }
      if (isTemplateError) {
        return fail(res, 503, 'SMS template not configured. Contact support.');
      }
      return fail(res, 503, 'Failed to send OTP. Please try again.');
    }

    const msg91Payload = {
      provider: smsResult?.provider || 'msg91',
      ...(smsResult?.response || {}),
      ...(smsResult?.fallback ? { fallback: true, reason: smsResult.reason } : {}),
    };

    try {
      await query(
        `INSERT INTO otp_logs (phone, otp, template_id, msg91_response, expires_at, verified)
         VALUES ($1, $2, $3, $4::jsonb, NOW() + ($5 || ' seconds')::interval, FALSE)`,
        [phoneHash, otpHash, templateId, JSON.stringify(msg91Payload), String(OTP_TTL_SECONDS)]
      );
    } catch (logError) {
      logger.warn('otp_log_insert_failed', { phone: maskedPhone, error: logError.message });
    }

    logger.info('otp_sent', {
      phone: maskedPhone,
      provider: smsResult?.provider || 'msg91',
      success: true,
    });

    if (logOtpToConsole) {
      console.log('OTP:', otp);
    }

    await redis.del(sendLockKey);
    const responseData = {};
    if (!isProd) {
      responseData.devOTP = otp;
    }
    return ok(res, responseData, 'OTP sent successfully');
  } catch (error) {
    logger.error('otp_send_error', { error: error.message });
    throw error;
  }
});

// POST /api/auth/verify-otp
const verifyOtp = asyncHandler(async (req, res) => {
  const phone = otpPhoneKey(req.validated?.body?.phone);
  const otp = normalizeOtp(req.validated?.body?.otp);
  const mfaToken = req.validated?.body?.mfaToken;
  const maskedPhone = maskPhone(phone);

  // Proceed with normal OTP verification
  const redisKey = `otp:${phone}`;
  const data = await redis.get(redisKey);
  if (!data) {
    return fail(res, 400, 'OTP expired or not requested');
  }

  let parsed;
  try {
    // Handle case where data might be null or undefined
    if (typeof data === 'string') {
      parsed = JSON.parse(data);
    } else if (typeof data === 'object') {
      parsed = data;
    } else {
      logger.warn('otp_verify_invalid_redis_data_type', { dataType: typeof data, phone: maskedPhone });
      return fail(res, 500, 'Invalid OTP data format');
    }
  } catch (error) {
    logger.warn('otp_verify_parse_error', { error: error.message, phone: maskedPhone });
    return fail(res, 500, 'Invalid OTP data format');
  }
  
  const attempts = Number(parsed?.attempts || 0);
  const storedHash = parsed?.otpHash;

  if (attempts >= OTP_MAX_ATTEMPTS) {
    await redis.del(redisKey);
    
    logger.warn('otp_verify_failed', {
      phone: maskedPhone,
      reason: 'max_attempts_reached',
      attempts: attempts
    });
    
    return fail(res, 400, 'Max attempts reached. Request a new OTP.');
  }

  const incomingHash = hashOtp(phone, otp);
  if (!timingSafeEqualStr(incomingHash, storedHash)) {
    // Track failed attempts per phone (account lockout)
    const lockoutKey = `lockout:${phone}`;
    let lockoutCount = 0;
    try {
      const existing = await redis.get(lockoutKey);
      lockoutCount = Number(existing || 0) + 1;
      await redis.set(lockoutKey, String(lockoutCount), 'EX', 3600);
    } catch (e) {
      lockoutCount = 1; // ignore lockout errors, don't block login
    }
    
    if (lockoutCount >= 10) {
      await redis.del(redisKey); // Clear OTP
      return fail(res, 429, 'Account temporarily locked for 1 hour due to too many failed attempts. Contact support.');
    }
    
    let remainingTtl = OTP_TTL_SECONDS;
    if (parsed.sentAt) {
      const elapsedSeconds = Math.floor((Date.now() - parsed.sentAt) / 1000);
      remainingTtl = Math.max(1, OTP_TTL_SECONDS - elapsedSeconds);
    }
    await redis.set(
      redisKey,
      JSON.stringify({ otpHash: storedHash, attempts: attempts + 1, sentAt: parsed.sentAt }),
      'EX',
      remainingTtl
    );

    logger.warn('otp_verify_failed', {
      phone: maskedPhone,
      redisKey,
      reason: 'invalid_otp',
      attempts: attempts + 1,
      hint: logOtpToConsole
        ? 'Check otp_dev_console log from send-otp; SMS must match that OTP exactly.'
        : undefined,
    });

    return fail(
      res,
      400,
      'Invalid OTP. Use the code from your latest SMS, or request a new OTP after the timer ends.',
      { attemptsLeft: Math.max(0, OTP_MAX_ATTEMPTS - (attempts + 1)) }
    );
  }

  await redis.del(redisKey);
  await query(
    `UPDATE otp_logs SET verified = TRUE
     WHERE id = (
       SELECT id FROM otp_logs
       WHERE phone = $1 AND otp = $2
       ORDER BY created_at DESC
       LIMIT 1
     )`,
    [sha256(phone), storedHash]
  );

  const user = await ensureUserForPhone(phone);

  // Check if MFA is enabled and verify if token provided
  if (mfaService.isMFAEnabled(user)) {
    if (!mfaToken) {
      return fail(res, 401, 'MFA token required', { requiresMFA: true });
    }

    const isValidMfa = mfaService.verifyToken(mfaToken, mfaService.resolveStoredSecret(user.mfaSecret));
    if (!isValidMfa) {
      if (sentry && sentry.addBreadcrumb) {
        sentry.addBreadcrumb({
          message: 'MFA verification failed during login',
          category: 'auth',
          level: 'warning',
          data: { userId: user.id, phone: maskedPhone }
        });
      }
      return fail(res, 401, 'Invalid MFA token');
    }
  }

  const tokens = generateTokens(user.id);
  const refreshTokenHash = sha256(tokens.refreshToken);
  await query('UPDATE users SET refresh_token_hash = $1 WHERE id = $2', [refreshTokenHash, user.id]);

  // Clear lockout on successful login
  await redis.del(`lockout:${phone}`);

  // Set user context in Sentry
  if (sentry && sentry.setUser) {
    sentry.setUser(user);
  }

  if (sentry && sentry.addBreadcrumb) {
    sentry.addBreadcrumb({
      message: 'User logged in successfully',
      category: 'auth',
      level: 'info',
      data: { userId: user.id, role: user.role, hasMFA: mfaService.isMFAEnabled(user) }
    });
  }

  logger.info('user_login_success', {
    userId: user.id,
    phone: maskedPhone,
    role: user.role,
    hasMFA: mfaService.isMFAEnabled(user)
  });

  logger.info('otp_verify_success', {
    phone: maskedPhone,
    userId: user.id,
    role: user.role
  });

  const { mfaSecret, ...safeUser } = user;

  return ok(
    res,
    {
      user: {
        ...safeUser,
        mfaEnabled: mfaService.isMFAEnabled(user)
      },
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      token: tokens.accessToken, // legacy alias for older frontends
    },
    'Logged in'
  );
});

// POST /api/auth/refresh-token
const refreshToken = asyncHandler(async (req, res) => {
  const token = req.validated?.body?.refreshToken;

  const decoded = verifyRefreshToken(token);
  const userId = Number(decoded?.id);
  if (!userId) {
    return fail(res, 401, 'Invalid or expired refresh token');
  }

  const { rows } = await query('SELECT id, refresh_token_hash FROM users WHERE id = $1', [userId]);
  const user = rows[0];
  if (!user) {
    return fail(res, 401, 'Invalid refresh token');
  }

  const incomingHash = sha256(token);
  if (!user.refresh_token_hash || !timingSafeEqualStr(incomingHash, user.refresh_token_hash)) {
    return fail(res, 401, 'Invalid refresh token');
  }

  const tokens = generateTokens(userId);
  await query('UPDATE users SET refresh_token_hash = $1 WHERE id = $2', [sha256(tokens.refreshToken), userId]);

  if (sentry && sentry.addBreadcrumb) {
    sentry.addBreadcrumb({
      message: 'Token refreshed',
      category: 'auth',
      level: 'info',
      data: { userId }
    });
  }

  return ok(
    res,
    { accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, token: tokens.accessToken },
    'Token refreshed'
  );
});

// POST /api/auth/dev-login
const devLogin = asyncHandler(async (req, res) => {
  const enabled =
    process.env.NODE_ENV !== 'production' &&
    String(process.env.DEV_AUTH_BYPASS_ENABLED || '').toLowerCase() === 'true';
  const secret = process.env.DEV_AUTH_BYPASS_SECRET;

  if (!enabled || !secret) {
    return fail(res, 404, 'Not found');
  }

  const phone = req.validated?.body?.phone;
  const incoming = req.validated?.body?.secret;
  const requestedRoleRaw = req.validated?.body?.role;
  const requestedRole =
    requestedRoleRaw === 'user'
      ? ROLES.CUSTOMER
      : [ROLES.ADMIN, ROLES.CUSTOMER, ROLES.DELIVERY, ROLES.STAFF].includes(requestedRoleRaw)
        ? requestedRoleRaw
        : undefined;

  if (!timingSafeEqualStr(incoming, secret)) {
    return fail(res, 401, 'Invalid secret');
  }

  let user = await ensureUserForPhone(phone);

  if (requestedRole && user.role !== requestedRole) {
    const { rows } = await query(
      'UPDATE users SET role = $1 WHERE id = $2 RETURNING id, phone, name, role',
      [requestedRole, user.id]
    );
    user = rows[0] || user;

    if (user.role === ROLES.DELIVERY) {
      await query(
        'INSERT INTO delivery_partners (user_id, is_online) VALUES ($1, FALSE) ON CONFLICT (user_id) DO NOTHING',
        [user.id]
      );
    }
  }
  const tokens = generateTokens(user.id);
  await query('UPDATE users SET refresh_token_hash = $1 WHERE id = $2', [sha256(tokens.refreshToken), user.id]);

  // Set user context in Sentry
  if (sentry && sentry.setUser) {
    sentry.setUser(user);
  }

  if (sentry && sentry.addBreadcrumb) {
    sentry.addBreadcrumb({
      message: 'User logged in via dev bypass',
      category: 'auth',
      level: 'info',
      data: { userId: user.id, role: user.role },
    });
  }

  return ok(
    res,
    { user, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, token: tokens.accessToken },
    'Logged in (dev bypass)'
  );
});

// GET /api/auth/me (protected)
const getMe = asyncHandler(async (req, res) => {
  const userId = Number(req.user?.id);
  if (!userId) {
    return fail(res, 401, 'Unauthorized');
  }

  const result = await query('SELECT id, phone, name, role FROM users WHERE id = $1', [userId]);
  const user = result.rows[0];

  if (!user) {
    return fail(res, 404, 'User not found');
  }

  return ok(res, { user }, 'Current user');
});

// POST /api/auth/logout (protected)
const logout = asyncHandler(async (req, res) => {
  const userId = Number(req.user?.id);
  const token = req.token;

  if (userId) {
    await query('UPDATE users SET refresh_token_hash = NULL WHERE id = $1', [userId]);
  }

  if (token) {
    const { blacklistToken } = require('../../middlewares/enhancedAuth.middleware');
    try {
      await blacklistToken(token);
    } catch (err) {
      logger.error('Logout blacklist failed:', err);
      return fail(res, 503, 'Logout service temporarily unavailable');
    }
  }

  return ok(res, {}, 'Logged out');
});

module.exports = {
  sendOtp,
  verifyOtp,
  refreshToken,
  getMe,
  logout,
};
