const normalizeClientIp = (raw) => {
  const value = String(raw || '').trim();
  if (value.startsWith('::ffff:')) return value.slice(7);
  return value;
};

const adminOnly = (req, res, next) => {
  const allowedIPs = (process.env.METRICS_ALLOWED_IPS || '127.0.0.1')
    .split(',')
    .map((ip) => ip.trim())
    .filter(Boolean);
  const clientIP = normalizeClientIp(req.ip || req.connection?.remoteAddress);
  if (allowedIPs.includes(clientIP)) {
    return next();
  }
  return res.status(403).json({ error: 'Forbidden' });
};

module.exports = { adminOnly };
