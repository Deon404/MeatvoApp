const express = require('express');
const router = express.Router();

const { protect, optionalAuth } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { couponValidateRateLimiter } = require('../../middlewares/rateLimiter');
const { ROLES } = require('../../utils/roles');

const { listCoupons, createCoupon, validateCoupon, updateCoupon, deleteCoupon } = require('./coupons.controller');
const { listCouponsSchema, createCouponSchema, validateCouponSchema, updateCouponSchema, deleteCouponSchema } = require('./coupons.validation');

router.get('/', optionalAuth, validate(listCouponsSchema), listCoupons);
router.post('/', protect, rbac(ROLES.ADMIN), validate(createCouponSchema), createCoupon);
router.patch('/:id', protect, rbac(ROLES.ADMIN), validate(updateCouponSchema), updateCoupon);
router.delete('/:id', protect, rbac(ROLES.ADMIN), validate(deleteCouponSchema), deleteCoupon);
router.post('/validate', couponValidateRateLimiter, validate(validateCouponSchema), validateCoupon);

module.exports = router;

