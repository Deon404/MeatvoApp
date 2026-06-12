const express = require('express');
const crypto = require('crypto');
const asyncHandler = require('express-async-handler');
const { query } = require('../db/postgres');
const { fail, ok } = require('../utils/response');
const { formatPhoneForE164 } = require('../utils/msg91');
const { sha256 } = require('../modules/auth/auth.service');

const router = express.Router();

const timingSafeEqualStr = (a, b) => {
  const sa = String(a || '');
  const sb = String(b || '');
  const ba = Buffer.from(sa);
  const bb = Buffer.from(sb);
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

const requireDevSecret = (req, res, next) => {
  const enabled =
    process.env.NODE_ENV !== 'production' &&
    String(process.env.DEV_AUTH_BYPASS_ENABLED || '').toLowerCase() === 'true';
  const secret = process.env.DEV_AUTH_BYPASS_SECRET;

  if (!enabled || !secret) {
    return fail(res, 404, 'Not found');
  }

  const incoming = req.headers['x-dev-secret'] || req.query.secret;
  if (!timingSafeEqualStr(incoming, secret)) {
    return fail(res, 401, 'Invalid secret');
  }

  return next();
};

// GET /api/debug/otp-logs?phone=+919876543210
router.get(
  '/otp-logs',
  requireDevSecret,
  asyncHandler(async (req, res) => {
    const rawPhone = req.query.phone;
    if (!rawPhone) {
      return fail(res, 400, 'Query param phone is required (E.164, e.g. +919876543210)');
    }

    const phoneE164 = formatPhoneForE164(rawPhone);
    const phoneHash = sha256(phoneE164);

    const { rows } = await query(
      `SELECT id,
              phone AS phone_hash,
              template_id,
              msg91_response,
              verified,
              created_at,
              expires_at
       FROM otp_logs
       WHERE phone = $1
       ORDER BY created_at DESC
       LIMIT 5`,
      [phoneHash]
    );

    const attempts = rows.map((row) => {
      const response = row.msg91_response || {};
      const httpHint =
        response.httpStatus ||
        (response.type === 'success' ? 200 : response.type ? 400 : null);
      return {
        id: row.id,
        phoneHash: row.phone_hash,
        templateId: row.template_id,
        verified: row.verified,
        createdAt: row.created_at,
        expiresAt: row.expires_at,
        msg91Type: response.type || response.status,
        msg91RequestId: response.request_id,
        httpStatusHint: httpHint,
        provider: response.provider,
      };
    });

    return ok(
      res,
      { phoneHash, attempts },
      'Last 5 OTP attempts (phone stored as SHA-256 hash only)'
    );
  })
);

module.exports = router;
