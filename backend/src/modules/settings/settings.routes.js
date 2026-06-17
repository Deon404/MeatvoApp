const express = require('express');
const router = express.Router();

const { validate } = require('../../middlewares/validate.middleware');
const { getSchema } = require('./settings.validation');
const {
  getTheme,
  getBanner,
  getAppInfo,
} = require('./settings.controller');

// Public: theme + banner + app info (used by customer app for branding)
router.get('/theme', validate(getSchema), getTheme);
router.get('/banner', validate(getSchema), getBanner);
router.get('/app-info', validate(getSchema), getAppInfo);

module.exports = router;
