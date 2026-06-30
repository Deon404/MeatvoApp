const { query } = require('../db/postgres');
const { logger } = require('./logger');

/**
 * Release a coupon's usage count when an order is cancelled.
 * Idempotent — safe to call multiple times for the same order.
 */
const releaseCouponForOrder = async (client, orderId) => {
  const db = client || { query };
  try {
    const { rows } = await db.query(
      `SELECT coupon_id, coupon_released_at 
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId]
    );
    const order = rows[0];
    if (!order || !order.coupon_id || order.coupon_released_at) {
      return { released: false };
    }

    await db.query(
      'UPDATE coupons SET used_count = used_count - 1 WHERE id = $1 AND used_count > 0',
      [order.coupon_id]
    );
    await db.query(
      'UPDATE orders SET coupon_released_at = NOW() WHERE id = $1',
      [orderId]
    );

    logger.info('coupon_released', { orderId, couponId: order.coupon_id });
    return { released: true };
  } catch (err) {
    logger.error('coupon_release_failed', { orderId, error: err.message });
    return { released: false, error: err.message };
  }
};

module.exports = { releaseCouponForOrder };
