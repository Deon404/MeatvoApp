const adminOnly = (req, res, next) => {
  const allowedIPs = (process.env.METRICS_ALLOWED_IPS || '127.0.0.1').split(',');
  const clientIP = req.ip || req.connection.remoteAddress;
  if (allowedIPs.some((ip) => clientIP.includes(ip.trim()))) {
    return next();
  }
  return res.status(403).json({ error: 'Forbidden' });
};

module.exports = { adminOnly };
