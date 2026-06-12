/**
 * Unified API response helpers.
 *
 * Standard envelope:
 *   { success, ok, data, message }           — 2xx
 *   { success, ok, error: { message, code? }, data, message } — 4xx/5xx
 *
 * `ok` mirrors `success` for backward compatibility with older clients.
 */

const ok = (res, data = {}, message = '') =>
  res.status(200).json({ ok: true, success: true, data, message });

const created = (res, data = {}, message = 'Created') =>
  res.status(201).json({ ok: true, success: true, data, message });

/**
 * @param {import('express').Response} res
 * @param {number} status   - 4xx / 5xx HTTP status code
 * @param {string} message  - human-readable error description
 * @param {object} [data]   - optional extra payload (e.g. { code, issues, ... })
 *
 * If `data.code` is present it is promoted to `error.code` for typed error handling.
 */
const fail = (res, status, message, data = {}) => {
  const { code, ...rest } = typeof data === 'object' && data !== null ? data : {};
  return res.status(status).json({
    ok: false,
    success: false,
    error: { message, ...(code ? { code } : {}) },
    data: Object.keys(rest).length ? rest : {},
    message,
  });
};

module.exports = { ok, created, fail };
