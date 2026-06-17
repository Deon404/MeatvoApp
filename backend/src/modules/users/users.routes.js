const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ok, created, fail } = require('../../utils/response');
const { query } = require('../../db/postgres');
const asyncHandler = require('express-async-handler');
const {
  getUserNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  getUnreadCount,
} = require('../../services/notification.service');
const {
  fcmTokenSchema,
  updateProfileSchema,
  wishlistProductSchema,
  submitReviewSchema,
} = require('./users.validation');

router.get('/me', protect, (req, res) => {
  return ok(
    res,
    {
      id: String(req.user.id),
      phone: req.user.phone,
      role: req.user.role,
      name: req.user.name || '',
      email: req.user.email || '',
      profile_image_url: req.user.profile_image_url || '',
    },
    'Me'
  );
});

router.post('/fcm-token', protect, validate(fcmTokenSchema), asyncHandler(async (req, res) => {
  try {
    const { fcm_token } = req.validated.body;
    await query('UPDATE users SET fcm_token = $1 WHERE id = $2', [fcm_token, req.user.id]);
    return ok(res, { success: true }, 'FCM token saved');
  } catch (error) {
    console.error('Error saving FCM token:', error);
    return res.status(500).json({ success: false, message: 'Failed to save FCM token' });
  }
}));

router.patch('/profile', protect, validate(updateProfileSchema), asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { name, email, profile_image_url } = req.validated.body;

  const { rows } = await query(
    `UPDATE users
     SET name = COALESCE($1, name),
         email = COALESCE($2, email),
         profile_image_url = COALESCE($3, profile_image_url),
         updated_at = NOW()
     WHERE id = $4
     RETURNING id, phone, role, name, email, profile_image_url`,
    [name ?? null, email ?? null, profile_image_url ?? null, userId]
  );

  if (!rows[0]) return fail(res, 404, 'User not found');
  return ok(res, rows[0], 'Profile updated');
}));

router.get('/notifications', protect, asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const unreadOnly = req.query.unreadOnly === 'true';
  const notifications = await getUserNotifications(req.user.id, { limit, unreadOnly });
  const unreadCount = await getUnreadCount(req.user.id);
  return ok(res, { notifications, unreadCount }, 'Notifications');
}));

router.patch('/notifications/:id/read', protect, asyncHandler(async (req, res) => {
  const success = await markNotificationRead(req.user.id, req.params.id);
  if (!success) return fail(res, 404, 'Notification not found');
  return ok(res, { read: true }, 'Notification marked read');
}));

router.post('/notifications/read-all', protect, asyncHandler(async (req, res) => {
  const count = await markAllNotificationsRead(req.user.id);
  return ok(res, { count }, 'All notifications marked read');
}));

router.get('/wishlist', protect, asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT w.product_id, w.created_at, p.name, p.price, p.image_url, p.is_active
     FROM wishlists w
     JOIN products p ON p.id = w.product_id
     WHERE w.user_id = $1
     ORDER BY w.created_at DESC`,
    [req.user.id]
  );
  return ok(res, {
    productIds: rows.map((r) => String(r.product_id)),
    items: rows.map((r) => ({
      productId: String(r.product_id),
      name: r.name,
      price: Number(r.price || 0),
      imageUrl: r.image_url,
      isActive: r.is_active,
      addedAt: r.created_at,
    })),
  }, 'Wishlist');
}));

router.post('/wishlist', protect, validate(wishlistProductSchema), asyncHandler(async (req, res) => {
  const productId = Number(req.validated.body.product_id);
  await query(
    `INSERT INTO wishlists (user_id, product_id) VALUES ($1, $2)
     ON CONFLICT (user_id, product_id) DO NOTHING`,
    [req.user.id, productId]
  );
  return created(res, { productId: String(productId) }, 'Added to wishlist');
}));

router.delete('/wishlist/:productId', protect, asyncHandler(async (req, res) => {
  const productId = Number(req.params.productId);
  await query(
    'DELETE FROM wishlists WHERE user_id = $1 AND product_id = $2',
    [req.user.id, productId]
  );
  return ok(res, { productId: String(productId) }, 'Removed from wishlist');
}));

router.put('/wishlist', protect, asyncHandler(async (req, res) => {
  const productIds = Array.isArray(req.body?.productIds)
    ? req.body.productIds.map((id) => Number(id)).filter((id) => Number.isFinite(id))
    : [];

  await query('DELETE FROM wishlists WHERE user_id = $1', [req.user.id]);
  for (const productId of productIds) {
    await query(
      `INSERT INTO wishlists (user_id, product_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [req.user.id, productId]
    );
  }
  return ok(res, { productIds: productIds.map(String) }, 'Wishlist synced');
}));

router.post('/reviews', protect, validate(submitReviewSchema), asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const {
    order_id: orderId,
    rider_rating: riderRating,
    product_quality_rating: productQualityRating,
    delivery_speed_rating: deliverySpeedRating,
    feedback,
  } = req.validated.body;

  const { rows: orderRows } = await query(
    'SELECT id, customer_id, status FROM orders WHERE id = $1',
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return fail(res, 404, 'Order not found');
  if (Number(order.customer_id) !== Number(userId)) {
    return fail(res, 403, 'Not your order');
  }
  if (order.status !== 'DELIVERED') {
    return fail(res, 400, 'Reviews allowed only for delivered orders');
  }

  const { rows } = await query(
    `INSERT INTO order_reviews
       (order_id, user_id, rider_rating, product_quality_rating, delivery_speed_rating, feedback)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (order_id, user_id) DO UPDATE SET
       rider_rating = EXCLUDED.rider_rating,
       product_quality_rating = EXCLUDED.product_quality_rating,
       delivery_speed_rating = EXCLUDED.delivery_speed_rating,
       feedback = EXCLUDED.feedback,
       updated_at = NOW()
     RETURNING *`,
    [orderId, userId, riderRating ?? null, productQualityRating ?? null, deliverySpeedRating ?? null, feedback ?? null]
  );

  if (productQualityRating) {
    const { rows: items } = await query(
      'SELECT product_id FROM order_items WHERE order_id = $1',
      [orderId]
    );
    for (const item of items) {
      await query(
        `INSERT INTO product_ratings (product_id, user_id, order_id, rating, review)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (product_id, user_id, order_id) DO UPDATE SET
           rating = EXCLUDED.rating,
           review = EXCLUDED.review,
           updated_at = NOW()`,
        [item.product_id, userId, orderId, productQualityRating, feedback ?? null]
      );
    }
  }

  return created(res, { review: rows[0] }, 'Review submitted');
}));

router.get('/reviews/order/:orderId', protect, asyncHandler(async (req, res) => {
  const orderId = Number(req.params.orderId);
  const { rows } = await query(
    'SELECT * FROM order_reviews WHERE order_id = $1 AND user_id = $2',
    [orderId, req.user.id]
  );
  return ok(res, { review: rows[0] || null }, 'Order review');
}));

module.exports = router;
