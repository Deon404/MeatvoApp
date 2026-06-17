const express = require('express');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const { query } = require('../../db/postgres');
const {
  verifyUploadSignature,
  UPLOAD_IMAGES_DIR,
} = require('../../utils/uploadSigning');
const { logger } = require('../../utils/logger');

const router = express.Router();

const MIME_BY_EXT = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
};

const resolveAuthUser = async (req) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) return null;

  try {
    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
      algorithms: ['HS256'],
    });
    if (decoded.type !== 'access') return null;

    const userId = Number(decoded.id);
    if (!userId) return null;

    const { rows } = await query('SELECT id, role FROM users WHERE id = $1', [userId]);
    return rows[0] || null;
  } catch {
    return null;
  }
};

const canAccessUpload = async (req, filename) => {
  const { exp, sig } = req.query;
  if (verifyUploadSignature(filename, exp, sig)) return true;

  const user = await resolveAuthUser(req);
  if (!user) return false;
  if (user.role === 'admin') return true;
  if (user.role === 'delivery' && filename.startsWith(`${user.id}_`)) return true;

  return false;
};

router.get('/images/:filename', async (req, res) => {
  const filename = path.basename(String(req.params.filename || ''));
  if (!filename || filename.includes('..')) {
    return res.status(400).json({ error: 'Invalid filename' });
  }

  const filePath = path.join(UPLOAD_IMAGES_DIR, filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }

  if (!(await canAccessUpload(req, filename))) {
    logger.warn('upload_access_denied', { filename, ip: req.ip });
    return res.status(403).json({ error: 'Valid signature or authorized access required' });
  }

  const ext = path.extname(filename).toLowerCase();
  const contentType = MIME_BY_EXT[ext] || 'application/octet-stream';

  res.setHeader('Content-Type', contentType);
  res.setHeader('Cache-Control', 'private, max-age=3600');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `inline; filename="${filename}"`);
  return res.sendFile(filePath);
});

module.exports = router;
