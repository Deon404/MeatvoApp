const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');

const computeDiscount = ({ discount_type, discount_value }, amount) => {
  if (discount_type === 'FLAT') return Math.min(amount, Number(discount_value));
  const pct = Number(discount_value);
  return Math.min(amount, (amount * pct) / 100);
};

const listCoupons = asyncHandler(async (req, res) => {
  const includeInactiveRequested = Boolean(req.validated?.query?.includeInactive);
  const includeInactive = req.user?.role === ROLES.ADMIN ? includeInactiveRequested : false;

  const params = [];
  let where = '';
  if (!includeInactive) {
    params.push(true);
    where = `WHERE active = $${params.length}`;
  }
  const { rows } = await query(
    `SELECT id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active
     FROM coupons ${where}
     ORDER BY id DESC`,
    params
  );
  return ok(res, { coupons: rows }, 'Coupons');
});

const createCoupon = asyncHandler(async (req, res) => {
  const body = req.validated.body;
  const code = body.code.toUpperCase();

  const { rows } = await query(
    `INSERT INTO coupons (code, discount_type, discount_value, min_order_value, max_uses, used_count, active)
     VALUES ($1,$2,$3,$4,$5,0,$6)
     RETURNING id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active`,
    [
      code,
      body.discount_type,
      body.discount_value,
      body.min_order_value ?? 0,
      body.max_uses ?? null,
      body.active ?? true,
    ]
  );
  return created(res, { coupon: rows[0] }, 'Coupon created');
});

const validateCoupon = asyncHandler(async (req, res) => {
  const code = req.validated.body.code.toUpperCase();
  const amount = Number(req.validated.body.amount);

  const { rows } = await query(
    `SELECT id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active
     FROM coupons WHERE code = $1`,
    [code]
  );
  const coupon = rows[0];
  if (!coupon || !coupon.active) return fail(res, 400, 'Invalid coupon');
  if (amount < Number(coupon.min_order_value || 0)) return fail(res, 400, 'Order amount too low for this coupon');
  if (coupon.max_uses !== null && Number(coupon.used_count) >= Number(coupon.max_uses)) {
    return fail(res, 400, 'Coupon usage limit reached');
  }

  const discount = computeDiscount(coupon, amount);
  const finalAmount = Math.max(0, amount - discount);
  return ok(
    res,
    { valid: true, coupon: { id: coupon.id, code: coupon.code }, discount, finalAmount },
    'Coupon valid'
  );
});

module.exports = {
  listCoupons,
  createCoupon,
  validateCoupon,
};

