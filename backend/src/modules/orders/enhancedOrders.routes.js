/**
 * Enhanced Orders Routes
 * API routes for enhanced order lifecycle
 */

const express = require('express');
const router = express.Router();
const { protect } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { ROLES } = require('../../utils/roles');
const {
  validateStateTransition,
  validateActorPermission,
  validateOrderOwnership,
  requireOrderState,
} = require('../../middlewares/orderState.middleware');
const {
  transitionState,
  getTimeline,
  getActions,
  getTracking,
  startPacking,
  markPacked,
  verifyPayment,
  acceptOrder,
  startDelivery,
  updateLocation,
  getDeliveryOTP,
  completeDelivery,
  getProof,
  getCODDetails,
  getNotifications,
  markRead,
  markAllRead,
  getUnreadNotificationCount,
} = require('./enhancedOrders.controller');

// ===== Order Lifecycle Endpoints =====

/**
 * Generic state transition endpoint
 * POST /api/orders/:id/transition
 * Body: { newState: string, notes?: string }
 */
router.post(
  '/:id/transition',
  protect,
  validateOrderOwnership,
  validateStateTransition,
  validateActorPermission,
  transitionState
);

/**
 * Get order timeline
 * GET /api/orders/:id/timeline
 */
router.get(
  '/:id/timeline',
  protect,
  validateOrderOwnership,
  getTimeline
);

/**
 * Get available actions for order
 * GET /api/orders/:id/actions
 */
router.get(
  '/:id/actions',
  protect,
  validateOrderOwnership,
  getActions
);

/**
 * Get real-time tracking info
 * GET /api/orders/:id/tracking
 */
router.get(
  '/:id/tracking',
  protect,
  validateOrderOwnership,
  getTracking
);

// ===== Admin Order Management =====

/**
 * Start packing order
 * POST /api/orders/:id/start-packing
 */
router.post(
  '/:id/start-packing',
  protect,
  rbac(ROLES.ADMIN),
  requireOrderState('CONFIRMED'),
  startPacking
);

/**
 * Mark order as packed
 * POST /api/orders/:id/mark-packed
 */
router.post(
  '/:id/mark-packed',
  protect,
  rbac(ROLES.ADMIN),
  requireOrderState('PACKING_STARTED', 'CONFIRMED'),
  markPacked
);

/**
 * Verify payment
 * POST /api/orders/:id/verify-payment
 */
router.post(
  '/:id/verify-payment',
  protect,
  rbac(ROLES.ADMIN),
  requireOrderState('PAYMENT_PENDING'),
  verifyPayment
);

// ===== Delivery Partner Endpoints =====

/**
 * Accept order
 * POST /api/orders/:id/accept
 */
router.post(
  '/:id/accept',
  protect,
  rbac(ROLES.DELIVERY),
  validateOrderOwnership,
  requireOrderState('RIDER_ASSIGNED'),
  acceptOrder
);

/**
 * Start delivery
 * POST /api/orders/:id/start-delivery
 */
router.post(
  '/:id/start-delivery',
  protect,
  rbac(ROLES.DELIVERY),
  validateOrderOwnership,
  requireOrderState('RIDER_ACCEPTED'),
  startDelivery
);

/**
 * Update rider location
 * POST /api/orders/location
 * Body: { lat: number, lng: number, orderId?: number }
 */
router.post(
  '/location',
  protect,
  rbac(ROLES.DELIVERY),
  updateLocation
);

/**
 * Complete delivery with verification
 * POST /api/orders/:id/complete
 * Body: {
 *   otp?: string,
 *   proofType?: 'photo' | 'signature',
 *   proofUrl?: string,
 *   customerName?: string,
 *   notes?: string,
 *   codAmount?: number
 * }
 */
router.post(
  '/:id/complete',
  protect,
  rbac(ROLES.DELIVERY),
  validateOrderOwnership,
  requireOrderState('OUT_FOR_DELIVERY', 'RIDER_NEARBY'),
  completeDelivery
);

// ===== Customer Endpoints =====

/**
 * Get delivery OTP
 * GET /api/orders/:id/delivery-otp
 */
router.get(
  '/:id/delivery-otp',
  protect,
  rbac(ROLES.CUSTOMER),
  validateOrderOwnership,
  requireOrderState('OUT_FOR_DELIVERY', 'RIDER_NEARBY'),
  getDeliveryOTP
);

// ===== Delivery Verification Endpoints (Admin/Customer) =====

/**
 * Get delivery proof
 * GET /api/orders/:id/delivery-proof
 */
router.get(
  '/:id/delivery-proof',
  protect,
  validateOrderOwnership,
  getProof
);

/**
 * Get COD verification
 * GET /api/orders/:id/cod-verification
 */
router.get(
  '/:id/cod-verification',
  protect,
  rbac(ROLES.ADMIN),
  getCODDetails
);

// ===== Notification Endpoints =====

/**
 * Get user notifications
 * GET /api/notifications
 * Query: limit?, unreadOnly?
 */
router.get(
  '/notifications',
  protect,
  getNotifications
);

/**
 * Mark notification as read
 * POST /api/notifications/:id/read
 */
router.post(
  '/notifications/:id/read',
  protect,
  markRead
);

/**
 * Mark all notifications as read
 * POST /api/notifications/read-all
 */
router.post(
  '/notifications/read-all',
  protect,
  markAllRead
);

/**
 * Get unread notification count
 * GET /api/notifications/unread-count
 */
router.get(
  '/notifications/unread-count',
  protect,
  getUnreadNotificationCount
);

module.exports = router;
