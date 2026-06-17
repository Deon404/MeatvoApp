const crypto = require('crypto');

const SUPPORTED_EVENT_TYPES = new Set([
  'PAYMENT_SUCCESS_WEBHOOK',
  'PAYMENT_FAILED_WEBHOOK',
  'PAYMENT_USER_DROPPED_WEBHOOK',
]);

const timingSafeEqualBase64 = (a, b) => {
  const ba = Buffer.from(String(a || ''), 'utf8');
  const bb = Buffer.from(String(b || ''), 'utf8');
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

const getRawBody = (req) => {
  if (req.rawBody != null) {
    return Buffer.isBuffer(req.rawBody) ? req.rawBody.toString('utf8') : String(req.rawBody);
  }
  if (typeof req.body === 'string') {
    return req.body;
  }
  if (Buffer.isBuffer(req.body)) {
    return req.body.toString('utf8');
  }
  return null;
};

const getWebhookTimestamp = (req) =>
  req.headers['x-webhook-ts'] ||
  req.headers['x-webhook-timestamp'] ||
  null;

const computeSignature = (timestamp, rawBody, secretKey) =>
  crypto
    .createHmac('sha256', secretKey)
    .update(String(timestamp) + rawBody)
    .digest('base64');

/**
 * Verify Cashfree webhook signature and parse payload.
 * Requires raw request body on req.rawBody (recommended) or req.body as string/Buffer.
 *
 * @param {import('express').Request} req
 * @returns {{ valid: boolean, payload: object|null }}
 */
function verifyCashfreeWebhook(req) {
  const secretKey = process.env.CASHFREE_SECRET_KEY;

  if (!secretKey) {
    return { valid: false, payload: null };
  }

  const signature = req.headers['x-webhook-signature'];
  const timestamp = getWebhookTimestamp(req);
  const rawBody = getRawBody(req);

  if (!signature || !timestamp || !rawBody) {
    return { valid: false, payload: null };
  }

  const expectedSignature = computeSignature(timestamp, rawBody, secretKey);
  if (!timingSafeEqualBase64(expectedSignature, signature)) {
    return { valid: false, payload: null };
  }

  try {
    const payload = JSON.parse(rawBody);
    return { valid: true, payload };
  } catch {
    return { valid: false, payload: null };
  }
}

const mapEventStatus = (eventType, paymentStatus) => {
  if (paymentStatus) return String(paymentStatus).toUpperCase();

  switch (eventType) {
    case 'PAYMENT_SUCCESS_WEBHOOK':
      return 'SUCCESS';
    case 'PAYMENT_FAILED_WEBHOOK':
      return 'FAILED';
    case 'PAYMENT_USER_DROPPED_WEBHOOK':
      return 'USER_DROPPED';
    default:
      return 'UNKNOWN';
  }
};

/**
 * Parse supported Cashfree webhook events into a normalized shape.
 *
 * @param {object} payload - Verified webhook JSON body
 * @returns {{ eventType: string, orderId: string|null, status: string, amount: number|null }}
 */
function parseCashfreeWebhookEvent(payload) {
  if (!payload || typeof payload !== 'object') {
    throw new Error('Cashfree webhook parse failed: payload must be an object');
  }

  const eventType = payload.type || payload.event || null;

  if (!eventType || !SUPPORTED_EVENT_TYPES.has(eventType)) {
    throw new Error(`Cashfree webhook parse failed: unsupported event type "${eventType}"`);
  }

  const order = payload.data?.order || {};
  const payment = payload.data?.payment || {};

  const orderId = order.order_id != null ? String(order.order_id) : null;
  const amount =
    payment.payment_amount != null
      ? Number(payment.payment_amount)
      : order.order_amount != null
        ? Number(order.order_amount)
        : null;

  return {
    eventType,
    orderId,
    status: mapEventStatus(eventType, payment.payment_status),
    amount: Number.isFinite(amount) ? amount : null,
  };
}

module.exports = {
  verifyCashfreeWebhook,
  parseCashfreeWebhookEvent,
};
