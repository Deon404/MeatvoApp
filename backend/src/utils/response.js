const ok = (res, data = {}, message = '') =>
  res.status(200).json({ ok: true, success: true, data, message });

const created = (res, data = {}, message = 'Created') =>
  res.status(201).json({ ok: true, success: true, data, message });

const fail = (res, status, message, data = {}) =>
  res.status(status).json({ ok: false, success: false, error: { message }, data, message });

module.exports = { ok, created, fail };
