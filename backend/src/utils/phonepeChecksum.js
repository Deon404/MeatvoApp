const crypto = require('crypto');

/**
 * PhonePe checksum helpers.
 * API calls sign base64 payloads; webhooks sign the raw base64 `response` field.
 */
const generateChecksum = (payload, saltKey, saltIndex) => {
  const stringToHash = String(payload) + String(saltKey);
  const hash = crypto.createHash('sha256').update(stringToHash).digest('hex');
  return `${hash}###${saltIndex}`;
};

const timingSafeEqualStr = (a, b) => {
  const sa = String(a || '');
  const sb = String(b || '');
  const ba = Buffer.from(sa);
  const bb = Buffer.from(sb);
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

const verifyChecksum = (payload, signature, saltKey, saltIndex) => {
  if (!signature || !saltKey) return false;
  const expected = generateChecksum(payload, saltKey, saltIndex);
  return timingSafeEqualStr(signature, expected);
};

/**
 * PhonePe callbacks send `{ response: "<base64>" }`.
 * Signature is computed on the base64 string, not decoded JSON.
 */
const parsePhonePeWebhookBody = (body) => {
  if (!body || typeof body !== 'object') {
    return { payloadForSignature: null, webhookBody: null };
  }

  if (typeof body.response === 'string' && body.response.trim()) {
    const base64Response = body.response.trim();
    let decoded = null;
    try {
      decoded = JSON.parse(Buffer.from(base64Response, 'base64').toString('utf8'));
    } catch {
      return { payloadForSignature: base64Response, webhookBody: null };
    }
    return { payloadForSignature: base64Response, webhookBody: decoded };
  }

  // Legacy/test format: direct JSON body (used in local curl tests).
  const canonical = JSON.stringify(body, Object.keys(body).sort());
  return { payloadForSignature: canonical, webhookBody: body };
};

module.exports = {
  generateChecksum,
  timingSafeEqualStr,
  verifyChecksum,
  parsePhonePeWebhookBody,
};
