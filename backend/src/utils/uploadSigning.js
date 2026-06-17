const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const DEFAULT_TTL_SECONDS = Number(process.env.UPLOAD_SIGN_TTL_SECONDS || 7 * 24 * 60 * 60);
const UPLOAD_PATH_PREFIX = '/uploads/images/';
const UPLOAD_IMAGES_DIR = path.join(__dirname, '../../uploads/images');

const getSigningSecret = () => {
  const secret = process.env.UPLOAD_SIGNING_SECRET || process.env.JWT_ACCESS_SECRET;
  if (!secret) throw new Error('UPLOAD_SIGNING_SECRET or JWT_ACCESS_SECRET is required');
  return secret;
};

const timingSafeEqualStr = (a, b) => {
  const ba = Buffer.from(String(a || ''));
  const bb = Buffer.from(String(b || ''));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

const signUploadFilename = (filename, expiresAt) => {
  const payload = `${filename}:${expiresAt}`;
  return crypto.createHmac('sha256', getSigningSecret()).update(payload).digest('base64url');
};

const buildSignedUploadPath = (filename, ttlSeconds = DEFAULT_TTL_SECONDS) => {
  const safeName = path.basename(String(filename || ''));
  const exp = Math.floor(Date.now() / 1000) + ttlSeconds;
  const sig = signUploadFilename(safeName, exp);
  return `${UPLOAD_PATH_PREFIX}${safeName}?exp=${exp}&sig=${sig}`;
};

const buildSignedUploadUrl = (baseUrl, filename, ttlSeconds = DEFAULT_TTL_SECONDS) => {
  const normalizedBase = String(baseUrl || '').replace(/\/$/, '');
  return `${normalizedBase}${buildSignedUploadPath(filename, ttlSeconds)}`;
};

const verifyUploadSignature = (filename, exp, sig) => {
  const safeName = path.basename(String(filename || ''));
  const expNum = Number(exp);
  if (!safeName || !sig || !Number.isFinite(expNum)) return false;
  if (expNum < Math.floor(Date.now() / 1000)) return false;
  const expected = signUploadFilename(safeName, expNum);
  return timingSafeEqualStr(sig, expected);
};

const extractUploadFilename = (imageUrl) => {
  if (!imageUrl || typeof imageUrl !== 'string') return null;

  try {
    const parsed = imageUrl.startsWith('http') ? new URL(imageUrl) : null;
    const pathname = parsed ? parsed.pathname : imageUrl.split('?')[0];
    if (!pathname.includes(UPLOAD_PATH_PREFIX)) return null;
    const filename = path.basename(pathname);
    if (!filename || filename === '.' || filename.includes('..')) return null;
    return filename;
  } catch {
    return null;
  }
};

/**
 * Canonical unsigned storage path for DB persistence.
 */
const normalizeStoredImageUrl = (imageUrl) => {
  const filename = extractUploadFilename(imageUrl);
  if (!filename) return imageUrl || '';
  return `${UPLOAD_PATH_PREFIX}${filename}`;
};

const isManagedUploadUrl = (imageUrl) => Boolean(extractUploadFilename(imageUrl));

const resolveUploadFilePath = (imageUrl) => {
  const filename = extractUploadFilename(imageUrl);
  if (!filename) return null;
  return path.join(UPLOAD_IMAGES_DIR, filename);
};

/**
 * Validate rider delivery proof references an uploaded file they own.
 */
const validateRiderProofUpload = (proofUrl, riderUserId) => {
  const filename = extractUploadFilename(proofUrl);
  if (!filename) {
    return { valid: false, reason: 'Proof must be a managed upload URL' };
  }

  const ownerPrefix = `${Number(riderUserId)}_`;
  if (!filename.startsWith(ownerPrefix)) {
    return { valid: false, reason: 'Proof file does not belong to this rider' };
  }

  const filePath = path.join(UPLOAD_IMAGES_DIR, filename);
  if (!fs.existsSync(filePath)) {
    return { valid: false, reason: 'Proof file not found' };
  }

  return {
    valid: true,
    storagePath: `${UPLOAD_PATH_PREFIX}${filename}`,
    filename,
  };
};

/**
 * Re-sign a stored image URL (full or relative) for API responses.
 */
const signStoredImageUrl = (imageUrl, baseUrl, ttlSeconds = DEFAULT_TTL_SECONDS) => {
  if (!imageUrl || typeof imageUrl !== 'string') return imageUrl || '';

  try {
    const parsed = imageUrl.startsWith('http') ? new URL(imageUrl) : null;
    const pathname = parsed ? parsed.pathname : imageUrl.split('?')[0];
    if (!pathname.includes(UPLOAD_PATH_PREFIX)) return imageUrl;

    const filename = path.basename(pathname);
    const signedPath = buildSignedUploadPath(filename, ttlSeconds);
    if (baseUrl) {
      return buildSignedUploadUrl(baseUrl, filename, ttlSeconds);
    }
    if (parsed) {
      return `${parsed.origin}${signedPath}`;
    }
    return signedPath;
  } catch {
    return imageUrl;
  }
};

module.exports = {
  DEFAULT_TTL_SECONDS,
  UPLOAD_PATH_PREFIX,
  UPLOAD_IMAGES_DIR,
  buildSignedUploadPath,
  buildSignedUploadUrl,
  verifyUploadSignature,
  extractUploadFilename,
  normalizeStoredImageUrl,
  isManagedUploadUrl,
  resolveUploadFilePath,
  validateRiderProofUpload,
  signStoredImageUrl,
};
