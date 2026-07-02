const { query } = require('../../db/postgres');

const resolveDb = (db) => (db && typeof db.query === 'function' ? db : { query });

const computeDiscountAmount = (coupon, orderAmount) => {
  if (coupon.discount_type === 'FLAT') {
    return Math.min(orderAmount, Number(coupon.discount_value));
  }
  const pct = Number(coupon.discount_value);
  return Math.min(orderAmount, (orderAmount * pct) / 100);
};

const formatMinOrder = (value) => {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return '0';
  return Number.isInteger(amount) ? String(amount) : amount.toFixed(2);
};

const findCouponByCode = async (code, { db, lockCoupon = false } = {}) => {
  const normalized = String(code || '').trim().toUpperCase();
  if (!normalized) return null;
  const executor = resolveDb(db);

  const { rows } = await executor.query(
    `SELECT id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active
     FROM coupons
     WHERE code = $1
     ${lockCoupon ? 'FOR UPDATE' : ''}`,
    [normalized]
  );
  return rows[0] || null;
};

const hasUserAlreadyUsedCoupon = async ({ couponId, userId, db }) => {
  const normalizedUserId = Number(userId);
  if (!Number.isFinite(normalizedUserId) || normalizedUserId <= 0) {
    return false;
  }

  const executor = resolveDb(db);
  const { rows } = await executor.query(
    `SELECT id
     FROM orders
     WHERE customer_id = $1
       AND coupon_id = $2
       AND coupon_released_at IS NULL
     LIMIT 1`,
    [normalizedUserId, couponId]
  );
  return Boolean(rows[0]);
};

/**
 * Shared coupon validation used by POST /api/coupons/validate and POST /api/orders/apply-coupon.
 *
 * @param {{ code: string, orderAmount: number, userId?: string, db?: { query: Function }, lockCoupon?: boolean }} params
 * @returns {Promise<
 *   | { valid: true, coupon: object, discountType: string, discountValue: number, discountAmount: number }
 *   | { valid: false, reason: string }
 * >}
 */
const validateCouponForOrder = async ({ code, orderAmount, userId, db, lockCoupon = false }) => {
  const coupon = await findCouponByCode(code, { db, lockCoupon });
  if (!coupon) {
    return { valid: false, reason: 'Coupon not found' };
  }
  if (!coupon.active) {
    return { valid: false, reason: 'Coupon is expired' };
  }

  const minOrder = Number(coupon.min_order_value || 0);
  if (orderAmount < minOrder) {
    return {
      valid: false,
      reason: `Minimum order ₹${formatMinOrder(minOrder)} required`,
    };
  }

  if (coupon.max_uses !== null && Number(coupon.used_count) >= Number(coupon.max_uses)) {
    return { valid: false, reason: 'Coupon limit reached' };
  }

  if (await hasUserAlreadyUsedCoupon({ couponId: coupon.id, userId, db })) {
    return { valid: false, reason: 'You have already used this coupon' };
  }

  const discountAmount = computeDiscountAmount(coupon, orderAmount);
  return {
    valid: true,
    coupon,
    discountType: coupon.discount_type,
    discountValue: Number(coupon.discount_value),
    discountAmount,
  };
};

module.exports = {
  computeDiscountAmount,
  findCouponByCode,
  hasUserAlreadyUsedCoupon,
  validateCouponForOrder,
};
