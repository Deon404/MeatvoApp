/**
 * Enhanced Orders Controller
 * New endpoints for enhanced order lifecycle management
 */

const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const {
  transitionOrderState,
  getOrderTimeline,
  getOrderActions,
  ORDER_STATES,
} = require('../../services/orderLifecycle.service');
const {
  getUserNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  getUnreadCount,
} = require('../../services/notification.service');
const {
  updateRiderLocation,
  getOrderTrackingInfo,
} = require('../../services/tracking.service');
const {
  createDeliveryOTP,
  verifyDeliveryOTP,
  completeDeliveryWithVerification,
  getDeliveryOTPForCustomer,
  getDeliveryProof,
  getCODVerification,
} = require('../../services/deliveryProof.service');
const { validateRiderProofUpload } = require('../../utils/uploadSigning');

/**
 * POST /api/orders/:id/transition
 * Transition order to new state with validation
 */
const transitionState = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const { newState, notes } = req.body;

  const io = req.app.get('io');

  const result = await transitionOrderState({
    orderId,
    newState,
    actor: req.user.id,
    actorRole: req.actorRole,
    context: { notes },
    io,
  });

  return ok(res, result, 'Order state updated');
});

/**
 * GET /api/orders/:id/timeline
 * Get order lifecycle timeline
 */
const getTimeline = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const timeline = await getOrderTimeline(orderId);
  return ok(res, { timeline }, 'Order timeline');
});

/**
 * GET /api/orders/:id/actions
 * Get available actions for current user
 */
const getActions = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const actions = await getOrderActions(orderId, req.user.id, req.user.role);
  return ok(res, { actions }, 'Available actions');
});

/**
 * GET /api/orders/:id/tracking
 * Get real-time order tracking info
 */
const getTracking = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const tracking = await getOrderTrackingInfo(orderId);
  return ok(res, tracking, 'Order tracking info');
});

/**
 * POST /api/orders/:id/start-packing
 * Admin starts packing an order
 */
const startPacking = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const io = req.app.get('io');

  const result = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.PACKING_STARTED,
    actor: req.user.id,
    actorRole: req.user.role,
    io,
  });

  return ok(res, result, 'Packing started');
});

/**
 * POST /api/orders/:id/mark-packed
 * Admin marks order as packed
 */
const markPacked = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const io = req.app.get('io');

  const result = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.PACKED,
    actor: req.user.id,
    actorRole: req.user.role,
    io,
  });

  return ok(res, result, 'Order marked as packed');
});

/**
 * POST /api/orders/:id/verify-payment
 * Admin verifies online payment
 */
const verifyPayment = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const io = req.app.get('io');

  const result = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.PAYMENT_VERIFIED,
    actor: req.user.id,
    actorRole: 'admin',
    io,
  });

  return ok(res, result, 'Payment verified');
});

/**
 * POST /api/delivery/orders/:id/accept
 * Rider accepts order
 */
const acceptOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const io = req.app.get('io');

  const result = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.RIDER_ACCEPTED,
    actor: req.user.id,
    actorRole: 'rider',
    io,
  });

  return ok(res, result, 'Order accepted');
});

/**
 * POST /api/delivery/orders/:id/start-delivery
 * Rider starts delivery
 */
const startDelivery = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const io = req.app.get('io');

  const result = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.OUT_FOR_DELIVERY,
    actor: req.user.id,
    actorRole: 'rider',
    io,
  });

  return ok(res, result, 'Delivery started');
});

/**
 * POST /api/delivery/location
 * Update rider location with ETA calculation
 */
const updateLocation = asyncHandler(async (req, res) => {
  const { lat, lng, orderId } = req.body;
  const io = req.app.get('io');

  const result = await updateRiderLocation({
    riderUserId: req.user.id,
    lat,
    lng,
    orderId: orderId ? Number(orderId) : null,
    io,
  });

  return ok(res, result, 'Location updated');
});

/**
 * GET /api/orders/:id/delivery-otp
 * Customer gets delivery OTP
 */
const getDeliveryOTP = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const customerId = req.user.id;

  const otp = await getDeliveryOTPForCustomer(orderId, customerId);

  return ok(res, { otp }, 'Delivery OTP');
});

/**
 * POST /api/delivery/orders/:id/complete
 * Rider completes delivery with verification
 */
const completeDelivery = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const {
    otp,
    proofType,
    proofUrl,
    customerName,
    notes,
    codAmount,
  } = req.body;
  const io = req.app.get('io');

  if (proofUrl) {
    const proofCheck = validateRiderProofUpload(proofUrl, req.user.id);
    if (!proofCheck.valid) {
      return fail(res, 400, proofCheck.reason);
    }
  }

  // Verify delivery
  const verification = await completeDeliveryWithVerification({
    orderId,
    riderUserId: req.user.id,
    otp,
    proofType,
    proofUrl,
    customerName,
    notes,
    codAmount,
  });

  if (!verification.success) {
    return fail(res, 400, verification.errors.join(', '));
  }

  // Transition to delivered
  const result = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.DELIVERED,
    actor: req.user.id,
    actorRole: 'rider',
    context: { customerName, notes },
    io,
  });

  return ok(
    res,
    { ...result, verification },
    'Delivery completed successfully'
  );
});

/**
 * GET /api/orders/:id/delivery-proof
 * Get delivery proof
 */
const getProof = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const proof = await getDeliveryProof(orderId, baseUrl);

  if (!proof) {
    return fail(res, 404, 'Delivery proof not found');
  }

  return ok(res, proof, 'Delivery proof');
});

/**
 * GET /api/orders/:id/cod-verification
 * Get COD verification details
 */
const getCODDetails = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id);
  const verification = await getCODVerification(orderId);

  if (!verification) {
    return fail(res, 404, 'COD verification not found');
  }

  return ok(res, verification, 'COD verification');
});

/**
 * GET /api/notifications
 * Get user notifications
 */
const getNotifications = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { limit, unreadOnly } = req.query;

  const notifications = await getUserNotifications(userId, {
    limit: limit ? Number(limit) : 50,
    unreadOnly: unreadOnly === 'true',
  });

  const unreadCount = await getUnreadCount(userId);

  return ok(res, { notifications, unreadCount }, 'Notifications');
});

/**
 * POST /api/notifications/:id/read
 * Mark notification as read
 */
const markRead = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const notificationId = req.params.id;

  const success = await markNotificationRead(userId, notificationId);

  if (!success) {
    return fail(res, 404, 'Notification not found');
  }

  return ok(res, {}, 'Notification marked as read');
});

/**
 * POST /api/notifications/read-all
 * Mark all notifications as read
 */
const markAllRead = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const count = await markAllNotificationsRead(userId);

  return ok(res, { count }, `${count} notifications marked as read`);
});

/**
 * GET /api/notifications/unread-count
 * Get unread notification count
 */
const getUnreadNotificationCount = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const count = await getUnreadCount(userId);

  return ok(res, { count }, 'Unread count');
});

module.exports = {
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
};
