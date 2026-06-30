const { logger } = require('../utils/logger');
const { fail } = require('../utils/response');

const errorHandler = (err, req, res, next) => {
  let statusCode =
    Number(err?.statusCode || err?.status) ||
    (res.statusCode && res.statusCode !== 200 ? res.statusCode : 500);

  const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
  let message =
    statusCode >= 500 && isProd ? 'Internal server error' : err?.message || 'Internal server error';

  const path = req.originalUrl || req.url || '';
  if (
    err?.code === '23503' &&
    /\/api(?:\/v1)?\/admin\/users\/\d+\/role$/.test(path.split('?')[0])
  ) {
    statusCode = 409;
    message =
      'Cannot remove rider role — this rider has order history. Role will be deactivated instead.';
  }

  const log = statusCode >= 500 ? logger.error.bind(logger) : logger.warn.bind(logger);

  log('request_error', {
    requestId: req.id || null,
    method: req.method,
    path: req.originalUrl || req.url,
    statusCode,
    message: err?.message,
    stack: err?.stack,
    userId: req.user?.id || null,
  });

  return fail(res, statusCode, message, { requestId: req.id || null });
};

module.exports = { errorHandler };
