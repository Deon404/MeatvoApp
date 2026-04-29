const express = require('express');
const router = express.Router();

const { protect, optionalAuth } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const { listBanners, createBanner, deleteBanner } = require('./banners.controller');
const { listBannersSchema, createBannerSchema, deleteBannerSchema } = require('./banners.validation');

router.get('/', optionalAuth, validate(listBannersSchema), listBanners);
router.post('/', protect, rbac(ROLES.ADMIN), validate(createBannerSchema), createBanner);
router.delete('/:id', protect, rbac(ROLES.ADMIN), validate(deleteBannerSchema), deleteBanner);

module.exports = router;

