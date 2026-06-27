/**
 * Public base URL for signed upload links returned to clients.
 * Prefers explicit env (production domain) over req-derived host/protocol.
 */
const getPublicBaseUrl = (req) => {
  const fromEnv =
    process.env.PUBLIC_URL ||
    process.env.BACKEND_ROOT_URL ||
    process.env.MEATVO_API_ROOT ||
    process.env.MEATVO_PUBLIC_URL;

  if (fromEnv && String(fromEnv).trim()) {
    return String(fromEnv).trim().replace(/\/+$/, '');
  }

  const host = req?.get?.('host');
  if (!host) return 'http://127.0.0.1:8080';

  let protocol = req.protocol || 'http';
  const forwardedProto = req.get('x-forwarded-proto');
  if (forwardedProto) {
    protocol = String(forwardedProto).split(',')[0].trim();
  }

  const enforceHttps = String(process.env.ENFORCE_HTTPS || '').toLowerCase() === 'true';
  const isLocal =
    host.startsWith('127.') ||
    host.startsWith('localhost') ||
    host.startsWith('10.0.2.2');

  if (enforceHttps && protocol === 'http' && !isLocal) {
    protocol = 'https';
  }

  return `${protocol}://${host}`;
};

module.exports = { getPublicBaseUrl };
