const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');
const { validateCouponForOrder } = require('./coupons.service');

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
  const { code, orderAmount, userId } = req.validated.body;

  const result = await validateCouponForOrder({ code, orderAmount, userId });
  if (!result.valid) {
    return fail(res, 400, result.reason);
  }

  return ok(
    res,
    {
      valid: true,
      discountType: result.discountType,
      discountValue: result.discountValue,
      discountAmount: result.discountAmount,
    },
    'Coupon valid'
  );
});

const updateCoupon = asyncHandler(async (req, res) => {
  const couponId = Number(req.validated.params.id);
  const body = req.validated.body;

  const { rows: existing } = await query('SELECT id FROM coupons WHERE id = $1', [couponId]);
  if (!existing[0]) return fail(res, 404, 'Coupon not found');

  const fields = [];
  const values = [];
  let idx = 1;
  for (const [key, column] of [
    ['discount_type', 'discount_type'],
    ['discount_value', 'discount_value'],
    ['min_order_value', 'min_order_value'],
    ['max_uses', 'max_uses'],
    ['active', 'active'],
  ]) {
    if (body[key] !== undefined) {
      fields.push(`${column} = $${idx++}`);
      values.push(body[key]);
    }
  }
  values.push(couponId);

  const { rows } = await query(
    `UPDATE coupons SET ${fields.join(', ')} WHERE id = $${idx}
     RETURNING id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active`,
    values
  );
  return ok(res, { coupon: rows[0] }, 'Coupon updated');
});

const deleteCoupon = asyncHandler(async (req, res) => {
  const couponId = Number(req.validated.params.id);
  const { rowCount } = await query('DELETE FROM coupons WHERE id = $1', [couponId]);
  if (!rowCount) return fail(res, 404, 'Coupon not found');
  return ok(res, { id: couponId }, 'Coupon deleted');
});

module.exports = {
  listCoupons,
  createCoupon,
  validateCoupon,
  updateCoupon,
  deleteCoupon,
};
