const express = require('express');
const router = express.Router();

const { protect, optionalAuth } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const { listCoupons, createCoupon, validateCoupon } = require('./coupons.controller');
const { listCouponsSchema, createCouponSchema, validateCouponSchema } = require('./coupons.validation');

router.get('/', optionalAuth, validate(listCouponsSchema), listCoupons);
router.post('/', protect, rbac(ROLES.ADMIN), validate(createCouponSchema), createCoupon);
router.post('/validate', validate(validateCouponSchema), validateCoupon);

module.exports = router;

