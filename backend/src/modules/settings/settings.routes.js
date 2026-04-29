const express = require('express');
const router = express.Router();

const { validate } = require('../../middlewares/validate.middleware');
const { getSchema } = require('./settings.validation');
const {
  getTheme,
  getBanner,
} = require('./settings.controller');

// Public: theme + banner (used by customer app for branding)
router.get('/theme', validate(getSchema), getTheme);
router.get('/banner', validate(getSchema), getBanner);

module.exports = router;
