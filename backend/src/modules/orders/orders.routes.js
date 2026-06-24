const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { orderCreateRateLimiter } = require('../../middlewares/rateLimiter');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const {
  createOrder,
  getOrders,
  getOrder,
  cancelOrder,
  getAllOrders,
  updateOrderStatus,
  applyCoupon,
} = require('./orders.controller');

const {
  createOrderSchema,
  getOrdersSchema,
  getOrderSchema,
  cancelOrderSchema,
  getAllOrdersSchema,
  updateOrderStatusSchema,
  applyCouponSchema,
} = require('./orders.validation');

// Static paths must come before dynamic /:id to avoid route shadowing
router.post('/apply-coupon', protect, validate(applyCouponSchema), applyCoupon);
router.get('/my', protect, validate(getOrdersSchema), getOrders);

// Admin routes (static - must be before /:id)
router.get('/admin', protect, rbac(ROLES.ADMIN), validate(getAllOrdersSchema), getAllOrders);
router.put('/admin/:id/status', protect, rbac(ROLES.ADMIN), validate(updateOrderStatusSchema), updateOrderStatus);

router.post('/', protect, orderCreateRateLimiter, validate(createOrderSchema), createOrder);
router.get('/', protect, validate(getOrdersSchema), getOrders);
router.get('/:id', protect, validate(getOrderSchema), getOrder);
router.put('/:id/cancel', protect, validate(cancelOrderSchema), cancelOrder);
router.put('/:id/status', protect, rbac(ROLES.ADMIN, ROLES.STAFF), validate(updateOrderStatusSchema), updateOrderStatus);


module.exports = router;
