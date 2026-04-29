const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
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

router.post('/', protect, validate(createOrderSchema), createOrder);
router.get('/', protect, validate(getOrdersSchema), getOrders);
router.get('/:id', protect, validate(getOrderSchema), getOrder);
router.put('/:id/cancel', protect, validate(cancelOrderSchema), cancelOrder);
router.post('/apply-coupon', protect, validate(applyCouponSchema), applyCoupon);

// Admin routes
router.get('/admin', protect, rbac(ROLES.ADMIN), validate(getAllOrdersSchema), getAllOrders);
router.put('/admin/:id/status', protect, rbac(ROLES.ADMIN), validate(updateOrderStatusSchema), updateOrderStatus);

// Compat
router.get('/my', protect, validate(getOrdersSchema), getOrders);
router.put('/:id/status', protect, updateOrderStatus);


module.exports = router;
