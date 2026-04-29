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

const OTP_TTL_SECONDS = Number(process.env.OTP_TTL_SECONDS || 600);
const OTP_MAX_ATTEMPTS = Number(process.env.OTP_MAX_ATTEMPTS || 3);
const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
const logOtpToConsole =
  !isProd && String(process.env.OTP_LOG_TO_CONSOLE || '').toLowerCase() !== 'false';

const generateOtpCode = () => String(crypto.randomInt(0, 10000)).padStart(4, '0');

const hashOtp = (phone, otp) => {
  const secret = process.env.OTP_HASH_SECRET;
  if (!secret) throw new Error('OTP_HASH_SECRET is required');
  return crypto.createHmac('sha256', secret).update(`${phone}:${otp}`).digest('hex');
};

const roleForNewUser = (phone) => {
  const adminPhones = (process.env.ADMIN_PHONES || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const deliveryPhones = (process.env.DELIVERY_PHONES || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (adminPhones.includes(phone)) return ROLES.ADMIN;
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

const ensureUserForPhone = async (phone) => {
  const existing = await query('SELECT id, phone, name, role FROM users WHERE phone = $1', [phone]);
  let user = existing.rows[0];

  if (!user) {
    const role = roleForNewUser(phone);
    const created = await query(
      'INSERT INTO users (phone, role) VALUES ($1, $2) RETURNING id, phone, name, role',
      [phone, role]
    );
    user = created.rows[0];
  } else {
    // Bootstrap roles via env allowlist without ever demoting an existing privileged user.
    const desiredRole = roleForNewUser(phone);
    const currentRole = user.role;
    const shouldPromoteToAdmin = desiredRole === ROLES.ADMIN && currentRole !== ROLES.ADMIN;
    const shouldPromoteToDelivery =
      desiredRole === ROLES.DELIVERY && currentRole !== ROLES.DELIVERY && currentRole !== ROLES.ADMIN;

    if (shouldPromoteToAdmin || shouldPromoteToDelivery) {
      const nextRole = shouldPromoteToAdmin ? ROLES.ADMIN : ROLES.DELIVERY;
      const updated = await query(
        'UPDATE users SET role = $1 WHERE id = $2 RETURNING id, phone, name, role',
        [nextRole, user.id]
      );
      user = updated.rows[0] || user;
    }
  }

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
    console.log('🔍 SEND OTP START');
    console.log('📋 Request body:', req.body);
    console.log('📋 Validated data:', req.validated);
    
    const phone = req.validated?.body?.phone;
    console.log('📱 Phone extracted:', phone);

    if (!phone) {
      console.error('❌ Phone is missing from validated data');
      return fail(res, 400, 'Phone number is required');
    }

    // Check blocked phones
    const blockedPhones = (process.env.BLOCKED_PHONES || '')
      .split(',')
      .map(p => p.trim())
      .filter(Boolean);
    
    if (blockedPhones.includes(phone)) {
      return fail(res, 403, 'This phone number is not allowed.');
    }

    // Track IPs per phone number (suspicious activity detection)
    const ipTrackKey = `ips:${phone}`;
    const currentIp = req.ip || req.connection.remoteAddress;
    await redis.sadd(ipTrackKey, currentIp);
    await redis.expire(ipTrackKey, 86400); // 24 hours
    
    const uniqueIps = await redis.scard(ipTrackKey);
    if (uniqueIps > 5) {
      logger.warn('suspicious_activity_multiple_ips', { 
        phone: phone.substring(0, 3) + '****',
        uniqueIpCount: uniqueIps,
        currentIp 
      });
      return fail(res, 429, 'Suspicious activity detected. Contact support.');
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
      return fail(res, 429, 'Account locked due to too many failed attempts. Try again later.');
    }

    // CHECK: Is there already a valid unexpired OTP for this number?
    const existingKey = `otp:${phone}`;
    const existingData = await redis.get(existingKey);
    
    if (existingData) {
      let remainingSeconds = OTP_TTL_SECONDS; // default fallback
      try {
        const parsed = JSON.parse(existingData);
        if (parsed.sentAt) {
          const elapsedSeconds = Math.floor((Date.now() - parsed.sentAt) / 1000);
          remainingSeconds = Math.max(0, OTP_TTL_SECONDS - elapsedSeconds);
        }
      } catch (e) {}
      
      return res.status(429).json({
        success: false,
        message: 'OTP already sent. Use existing OTP.',
        data: {
          remainingSeconds,
          canResendAt: Date.now() + (remainingSeconds * 1000)
        }
      });
    }
    
    // No existing OTP → proceed to generate new one
    const otp = generateOtpCode();
    if (logOtpToConsole) {
      if (isProd) {
        console.log(`[OTP][${phone}] ${otp.substring(0, 2)}****`); // Masked in production
      } else {
        console.log(`[OTP][${phone}] ${otp}`); // Full OTP in development only
      }
    }
    const otpHash = hashOtp(phone, otp);
    const redisKey = `otp:${phone}`;
    
    console.log('🔐 OTP generated and hashed');

    console.log('💾 Storing OTP in Redis...');
    await redis.set(
      redisKey,
      JSON.stringify({ otpHash, attempts: 0, sentAt: Date.now() }),
      'EX',
      OTP_TTL_SECONDS
    );
    console.log('✅ OTP stored in Redis');

    console.log('📝 Inserting OTP log in database...');
    await query(
      'INSERT INTO otp_logs (phone, otp, expires_at, verified) VALUES ($1, $2, NOW() + ($3 || \' seconds\')::interval, FALSE)',
      [phone, otpHash, String(OTP_TTL_SECONDS)]
    );
    console.log('✅ OTP log inserted in database');

    console.log('📨 Sending SMS...');
    await sendOtpSms({ phone, otp });
    console.log('✅ SMS sent successfully');

    // STRUCTURED LOGGING (Low) - Log OTP send event with masked phone
    const maskedPhone = phone.length > 4 ? 
      phone.substring(0, 2) + '******' + phone.substring(phone.length - 2) : 
      '****';
    console.log(JSON.stringify({
      event: 'otp_sent',
      phone: maskedPhone,
      timestamp: new Date().toISOString(),
      success: true
    }));

    const responseData = {};
    if (logOtpToConsole) {
      responseData.devOTP = otp;
    }
    
    console.log('🎉 SEND OTP SUCCESS');
    return ok(res, responseData, 'OTP sent successfully');
    
  } catch (error) {
    console.error('❌ SEND OTP ERROR:', error);
    console.error('❌ Error stack:', error.stack);
    throw error; // Re-throw to let error handler catch it
  }
});

// POST /api/auth/verify-otp
const verifyOtp = asyncHandler(async (req, res) => {
  const phone = req.validated?.body?.phone;
  const otp = req.validated?.body?.otp;
  const mfaToken = req.validated?.body?.mfaToken;

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
      console.error('Invalid data type from Redis:', typeof data, data);
      return fail(res, 500, 'Invalid OTP data format');
    }
  } catch (error) {
    console.error('JSON parse error in verifyOtp:', error);
    console.error('Data received:', data);
    return fail(res, 500, 'Invalid OTP data format');
  }
  
  const attempts = Number(parsed?.attempts || 0);
  const storedHash = parsed?.otpHash;

  if (attempts >= OTP_MAX_ATTEMPTS) {
    await redis.del(redisKey);
    
    // STRUCTURED LOGGING (Low) - Log max attempts reached
    const maskedPhone = phone.length > 4 ? 
      phone.substring(0, 2) + '******' + phone.substring(phone.length - 2) : 
      '****';
    console.log(JSON.stringify({
      event: 'otp_verify_failed',
      phone: maskedPhone,
      timestamp: new Date().toISOString(),
      reason: 'max_attempts_reached',
      attempts: attempts
    }));
    
    return fail(res, 400, 'Max attempts reached. Request a new OTP.');
  }

  const incomingHash = hashOtp(phone, otp);
  if (incomingHash !== storedHash) {
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
    
    // Calculate remaining TTL before updating
    const remainingTtl = OTP_TTL_SECONDS; // use full TTL as safe fallback
    await redis.set(
      redisKey, 
      JSON.stringify({ otpHash: storedHash, attempts: attempts + 1, sentAt: parsed.sentAt }),
      'EX',
      remainingTtl
    );
    
    // STRUCTURED LOGGING (Low) - Log invalid OTP attempt
    const maskedPhone = phone.length > 4 ? 
      phone.substring(0, 2) + '******' + phone.substring(phone.length - 2) : 
      '****';
    console.log(JSON.stringify({
      event: 'otp_verify_failed',
      phone: maskedPhone,
      timestamp: new Date().toISOString(),
      reason: 'invalid_otp',
      attempts: attempts + 1
    }));
    
    return fail(res, 400, `Invalid OTP. Please try again. (${lockoutCount}/10 attempts)`);
  }

  await redis.del(redisKey);
  await query(
    'UPDATE otp_logs SET verified = TRUE WHERE id = (SELECT id FROM otp_logs WHERE phone = $1 AND otp = $2 ORDER BY created_at DESC LIMIT 1)',
    [phone, storedHash]
  );

  const user = await ensureUserForPhone(phone);

  // Check if MFA is enabled and verify if token provided
  if (mfaService.isMFAEnabled(user)) {
    if (!mfaToken) {
      return fail(res, 401, 'MFA token required', { requiresMFA: true });
    }

    const isValidMfa = mfaService.verifyToken(mfaToken, user.mfaSecret);
    if (!isValidMfa) {
      if (sentry && sentry.addBreadcrumb) {
        sentry.addBreadcrumb({
          message: 'MFA verification failed during login',
          category: 'auth',
          level: 'warning',
          data: { userId: user.id, phone: phone.substring(0, 3) + '******' }
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
    phone: phone.substring(0, 3) + '******',
    role: user.role,
    hasMFA: mfaService.isMFAEnabled(user)
  });

  // STRUCTURED LOGGING (Low) - Log successful OTP verification
  const maskedPhone = phone.length > 4 ? 
    phone.substring(0, 2) + '******' + phone.substring(phone.length - 2) : 
    '****';
  console.log(JSON.stringify({
    event: 'otp_verify_success',
    phone: maskedPhone,
    timestamp: new Date().toISOString(),
    userId: user.id,
    role: user.role
  }));

  return ok(
    res,
    {
      user: {
        ...user,
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
  if (!user.refresh_token_hash || user.refresh_token_hash !== incomingHash) {
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
  const enabled = String(process.env.DEV_AUTH_BYPASS_ENABLED || '').toLowerCase() === 'true';
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
      : [ROLES.ADMIN, ROLES.CUSTOMER, ROLES.DELIVERY].includes(requestedRoleRaw)
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

  sentry.addBreadcrumb({
    message: 'User logged in via dev bypass',
    category: 'auth',
    level: 'info',
    data: { userId: user.id, role: user.role }
  });

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
    blacklistToken(token);
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
