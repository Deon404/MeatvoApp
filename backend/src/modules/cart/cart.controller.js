const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { readCartMap, writeCartMap, clearCart: clearCartService } = require('./cart.service');
const { signStoredImageUrl } = require('../../utils/uploadSigning');
const { resolveUnitSalePrice } = require('../../utils/productPricing.util');

const PRODUCT_SELECT = `SELECT id, name, price, base_price_per_kg, weight_variants,
                               unit, image_url, active, stock
                        FROM products`;

const cartMapToArray = async (map, req) => {
  const entries = Object.entries(map || {})
    .map(([productId, quantity]) => ({ productId: String(productId), quantity: Number(quantity) }))
    .filter((it) => it.productId && Number.isFinite(it.quantity) && it.quantity > 0);

  if (entries.length === 0) return [];

  const productIds = entries.map((e) => Number(e.productId)).filter((n) => Number.isFinite(n) && n > 0);
  if (productIds.length === 0) return [];

  const { rows } = await query(
    `${PRODUCT_SELECT} WHERE id = ANY($1::bigint[])`,
    [productIds]
  );

  const byId = new Map(rows.map((p) => [String(p.id), p]));
  const baseUrl = `${req.protocol}://${req.get('host')}`;
  return entries
    .map((e) => {
      const p = byId.get(e.productId);
      if (!p) return null;
      const unitPrice = resolveUnitSalePrice(p);
      return {
        productId: e.productId,
        quantity: e.quantity,
        product: {
          id: String(p.id),
          name: p.name,
          price: unitPrice,
          display_price: unitPrice,
          base_price_per_kg: Number(p.base_price_per_kg || 0) || null,
          unit: p.unit || '',
          imageUrl: signStoredImageUrl(p.image_url || '', baseUrl),
          isActive: Boolean(p.active),
          inStock: Number(p.stock) > 0,
        },
      };
    })
    .filter(Boolean);
};

const sumCartTotal = (items) =>
  items.reduce((sum, item) => sum + Number(item.product.price) * item.quantity, 0);

const resolveCartProductId = (validated = {}) => {
  const bodyId = validated.body?.productId;
  const paramId = validated.params?.itemId || validated.params?.productId;
  return String(bodyId ?? paramId ?? '').trim();
};

const getCart = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const map = await readCartMap(userId);
  const items = await cartMapToArray(map, req);
  const total = sumCartTotal(items);

  return ok(res, { items, total: Number(total.toFixed(2)), itemCount: items.length });
});

// Helper for stock check
const checkStock = async (pid, qty) => {
  const { rows } = await query(
    'SELECT stock FROM products WHERE id = $1 AND active = true',
    [pid]
  );
  if (!rows[0] || Number(rows[0].stock) < qty) {
    return { valid: false, message: 'Insufficient stock' };
  }
  return { valid: true };
};

// POST /api/cart/add
const addToCart = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const { productId, quantity } = req.validated.body;
  const pid = Number(productId);
  const qty = Number(quantity);

  if (!pid || Number.isNaN(pid) || pid <= 0) return fail(res, 400, 'Invalid productId');
  if (!qty || qty < 1 || qty > 10) return fail(res, 400, 'Quantity must be 1-10');

  const stockCheck = await checkStock(pid, qty);
  if (!stockCheck.valid) return fail(res, 400, stockCheck.message);

  const map = await readCartMap(userId);
  const currentQty = Number(map[productId] || 0);
  const newQty = currentQty + qty;

  map[productId] = newQty;
  await writeCartMap(userId, map);

  const items = await cartMapToArray(map, req);
  const total = sumCartTotal(items);

  return ok(res, { cart: { items, total: Number(total.toFixed(2)), itemCount: items.length } }, 'Added to cart');
});

// PUT /api/cart/update
const updateCartItem = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const { quantity } = req.validated.body;
  const productId = resolveCartProductId(req.validated);
  const pid = Number(productId);
  const qty = Number(quantity);

  if (!pid || Number.isNaN(pid) || pid <= 0) return fail(res, 400, 'Invalid productId');

  const map = await readCartMap(userId);
  if (qty === 0) {
    delete map[productId];
  } else {
    const stockCheck = await checkStock(pid, qty);
    if (!stockCheck.valid) return fail(res, 400, stockCheck.message);
    map[productId] = qty;
  }

  await writeCartMap(userId, map);
  const items = await cartMapToArray(map, req);
  const total = sumCartTotal(items);

  return ok(res, { cart: { items, total: Number(total.toFixed(2)), itemCount: items.length } });
});

// DELETE /api/cart/remove/:productId
const removeFromCart = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const productId = resolveCartProductId(req.validated);
  const pid = Number(productId);

  if (!pid || Number.isNaN(pid) || pid <= 0) return fail(res, 400, 'Invalid productId');

  const map = await readCartMap(userId);
  delete map[productId];
  await writeCartMap(userId, map);

  const items = await cartMapToArray(map, req);
  const total = sumCartTotal(items);

  return ok(res, { cart: { items, total: Number(total.toFixed(2)), itemCount: items.length } });
});

// DELETE /api/cart/clear
const clearCart = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  await clearCartService(userId);
  return ok(res, {}, 'Cart cleared');
});

// GET /api/cart/count
const getCartCount = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const map = await readCartMap(userId);
  const entries = Object.entries(map || {}).filter(([_, q]) => Number(q) > 0);
  return ok(res, { count: entries.length });
});

module.exports = { getCart, addToCart, updateCartItem, removeFromCart, clearCart, getCartCount };
