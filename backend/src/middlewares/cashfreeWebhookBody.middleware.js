const express = require('express');

const CASHFREE_WEBHOOK_PATHS = new Set([
  '/api/payments/cashfree/webhook',
  '/api/v1/payments/cashfree/webhook',
]);

const isCashfreeWebhookRequest = (req) =>
  req.method === 'POST' && CASHFREE_WEBHOOK_PATHS.has(req.path);

const rawJsonParser = express.raw({ type: 'application/json', limit: '1mb' });
const jsonParser = express.json({ limit: '1mb' });

/**
 * Capture the raw request body for Cashfree webhook signature verification.
 * Must run before express.json() so the stream is not consumed as a parsed object.
 */
const captureCashfreeWebhookRawBody = (req, res, next) => {
  if (!isCashfreeWebhookRequest(req)) {
    return next();
  }

  return rawJsonParser(req, res, (err) => {
    if (err) return next(err);
    if (req.body != null) {
      req.rawBody = Buffer.isBuffer(req.body)
        ? req.body
        : Buffer.from(String(req.body), 'utf8');
    }
    next();
  });
};

/**
 * Apply express.json() to all routes except the Cashfree webhook paths
 * (those use captureCashfreeWebhookRawBody instead).
 */
const parseJsonUnlessCashfreeWebhook = (req, res, next) => {
  if (isCashfreeWebhookRequest(req)) {
    return next();
  }
  return jsonParser(req, res, next);
};

module.exports = {
  captureCashfreeWebhookRawBody,
  parseJsonUnlessCashfreeWebhook,
};
