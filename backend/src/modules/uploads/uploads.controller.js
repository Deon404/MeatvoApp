const path = require('path');
const fs = require('fs');
const multer = require('multer');
const asyncHandler = require('express-async-handler');
const { ok, fail } = require('../../utils/response');
const fileSecurity = require('../../security/file.security');
const { buildSignedUploadUrl, UPLOAD_PATH_PREFIX } = require('../../utils/uploadSigning');

const UPLOAD_DIR = path.join(__dirname, '../../../uploads/images');

if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const secureName = fileSecurity.generateSecureFilename(
      file.originalname,
      req.user?.id
    );
    cb(null, secureName);
  },
});

const imageFilter = (_req, file, cb) => {
  const allowed = new Set([
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
  ]);
  if (allowed.has(file.mimetype)) {
    cb(null, true);
    return;
  }
  cb(new Error('Only image files are allowed (JPEG, PNG, GIF, WebP)'));
};

const upload = multer({
  storage,
  limits: { fileSize: fileSecurity.maxFileSize },
  fileFilter: imageFilter,
});

const handleMulterError = (err, req, res, next) => {
  if (!err) return next();

  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return fail(res, 400, 'File too large. Maximum size is 5MB', { code: 'FILE_TOO_LARGE' });
    }
    return fail(res, 400, err.message, { code: 'UPLOAD_ERROR' });
  }

  if (err.message?.includes('Only image files')) {
    return fail(res, 400, err.message, { code: 'INVALID_FILE_TYPE' });
  }

  return fail(res, 400, err.message || 'Upload failed', { code: 'UPLOAD_ERROR' });
};

const uploadImageMiddleware = upload.single('image');

const uploadImage = asyncHandler(async (req, res) => {
  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const storagePath = `${UPLOAD_PATH_PREFIX}${req.file.filename}`;
  const signedUrl = buildSignedUploadUrl(baseUrl, req.file.filename);
  const relativePath = signedUrl.replace(baseUrl, '');

  return ok(
    res,
    {
      url: signedUrl,
      path: relativePath,
      storagePath,
      filename: req.file.filename,
    },
    'Image uploaded'
  );
});

const secureImageUploadMiddleware = [
  uploadImageMiddleware,
  handleMulterError,
  fileSecurity.validateFile,
  fileSecurity.scanFiles,
];

module.exports = {
  uploadImageMiddleware,
  handleMulterError,
  uploadImage,
  secureImageUploadMiddleware,
};
