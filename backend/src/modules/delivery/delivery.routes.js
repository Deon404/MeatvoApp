const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { requireDeliveryPartner } = require('../../middlewares/deliveryPartner.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const { secureImageUploadMiddleware, uploadImage } = require('../uploads/uploads.controller');

const {
  getMe,
  listAvailableOrders,
  listOrdersForDeliveryApp,
  acceptOrder,
  rejectOrder,
  markOrderFailedDelivery,
  confirmOrderReturnToStore,
  reportOperationalException,
  updateDeliveryOrderStatus,
  updateLocation,
  getEarnings,
  toggleOnline,
  updateProfile,
  bulkAssignZones,
  getMyOptimizedRoute,
  getOptimizedRouteForRider,
  getAdminOptimizedRoute,
  assignMultiRiderRoutes,
} = require('./delivery.controller');

const {
  getAvailableSlots,
  bookSlot,
  releaseSlot,
  getSlotById,
} = require('./slots.controller');

const {
  getMeSchema,
  listAvailableOrdersSchema,
  acceptOrderSchema,
  rejectOrderSchema,
  updateDeliveryOrderStatusSchema,
  markFailedDeliverySchema,
  confirmReturnToStoreSchema,
  reportOperationalExceptionSchema,
  updateLocationSchema,
  getEarningsSchema,
  toggleOnlineSchema,
  updateProfileSchema,
  bulkAssignZonesSchema,
} = require('./delivery.validation');

// Public routes - no auth required
router.get('/slots', getAvailableSlots);
router.get('/slots/:id', getSlotById);

// Admin zone assignment (admin JWT; must be before delivery-only guard)
router.put(
  '/orders/bulk-assign',
  protect,
  rbac(ROLES.ADMIN),
  validate(bulkAssignZonesSchema),
  bulkAssignZones
);

// Admin route optimization endpoints
router.get(
  '/route/optimize',
  protect,
  rbac(ROLES.ADMIN),
  getOptimizedRouteForRider
);

router.get(
  '/admin/route/optimize',
  protect,
  rbac(ROLES.ADMIN),
  getAdminOptimizedRoute
);

router.post(
  '/admin/assign-routes',
  protect,
  rbac(ROLES.ADMIN),
  assignMultiRiderRoutes
);

router.post(
  '/slots/:id/release',
  protect,
  rbac(ROLES.ADMIN),
  releaseSlot
);

// Protected routes for delivery partners
router.use(protect, requireDeliveryPartner);

router.get('/me', validate(getMeSchema), getMe);
router.get('/orders', validate(listAvailableOrdersSchema), listOrdersForDeliveryApp);
router.get('/orders/available', validate(listAvailableOrdersSchema), listAvailableOrders);
router.post('/orders/:id/claim', validate(acceptOrderSchema), acceptOrder);
router.put('/orders/:id/accept', validate(acceptOrderSchema), acceptOrder); // legacy
router.post('/orders/:id/accept', validate(acceptOrderSchema), acceptOrder);
router.post('/orders/:id/reject', validate(rejectOrderSchema), rejectOrder);
router.post('/orders/:id/failed-delivery', validate(markFailedDeliverySchema), markOrderFailedDelivery);
router.post('/orders/:id/return-to-store', validate(confirmReturnToStoreSchema), confirmOrderReturnToStore);
router.post(
  '/orders/:id/operational-exception',
  validate(reportOperationalExceptionSchema),
  reportOperationalException
);
router.patch('/orders/:id/status', validate(updateDeliveryOrderStatusSchema), updateDeliveryOrderStatus);
router.put('/orders/:id/status', validate(updateDeliveryOrderStatusSchema), updateDeliveryOrderStatus); // legacy
router.post('/online', validate(toggleOnlineSchema), toggleOnline);
router.put('/toggle-online', validate(toggleOnlineSchema), toggleOnline); // legacy
router.put('/location', validate(updateLocationSchema), updateLocation);
router.post('/location/update', validate(updateLocationSchema), updateLocation);
router.get('/earnings', validate(getEarningsSchema), getEarnings);
router.patch('/profile', validate(updateProfileSchema), updateProfile);
router.post('/upload/proof', ...secureImageUploadMiddleware, uploadImage);

// Rider's optimized route (own deliveries)
router.get('/my-route', getMyOptimizedRoute);

// Slot booking routes (protected)
router.post('/slots/:id/book', protect, bookSlot);

module.exports = router;
