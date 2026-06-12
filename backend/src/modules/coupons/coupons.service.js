const { query } = require('../../db/postgres');

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

const findCouponByCode = async (code) => {
  const normalized = String(code || '').trim().toUpperCase();
  if (!normalized) return null;

  const { rows } = await query(
    `SELECT id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active
     FROM coupons
     WHERE code = $1`,
    [normalized]
  );
  return rows[0] || null;
};

/**
 * Shared coupon validation used by POST /api/coupons/validate and POST /api/orders/apply-coupon.
 *
 * @param {{ code: string, orderAmount: number, userId?: string }} params
 * @returns {Promise<
 *   | { valid: true, coupon: object, discountType: string, discountValue: number, discountAmount: number }
 *   | { valid: false, reason: string }
 * >}
 */
const validateCouponForOrder = async ({ code, orderAmount, userId }) => {
  void userId;

  const coupon = await findCouponByCode(code);
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
  validateCouponForOrder,
};
