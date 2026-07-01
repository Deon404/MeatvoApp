const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { readCartMap, writeCartMap, clearCart: clearCartService, normalizeCartEntry, gramsFromVariantId } = require('./cart.service');
const { signStoredImageUrl } = require('../../utils/uploadSigning');
const { resolveUnitSalePrice, defaultWeightGrams } = require('../../utils/productPricing.util');

const PRODUCT_SELECT = `SELECT id, name, price, base_price_per_kg, weight_variants,
                               unit, image_url, active, stock
                        FROM products`;

const formatWeightLabel = (grams) => {
  if (!grams || grams <= 0) return '';
  if (grams >= 1000 && grams % 1000 === 0) return `${grams / 1000}kg`;
  if (grams >= 1000) {
    const kg = grams / 1000;
    return Number.isInteger(kg) ? `${kg}kg` : `${kg.toFixed(1)}kg`;
  }
  return `${grams}g`;
};

const cartMapToArray = async (map, req) => {
  const entries = Object.entries(map || {})
    .map(([productId, raw]) => {
      const entry = normalizeCartEntry(raw);
      return { productId: String(productId), ...entry };
    })
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
      const weightGrams =
        e.weightGrams ||
        gramsFromVariantId(e.variantId) ||
        defaultWeightGrams(p.weight_variants);
      const unitPrice = resolveUnitSalePrice(p, weightGrams);
      const unitLabel = formatWeightLabel(weightGrams) || p.unit || '';
      return {
        productId: e.productId,
        quantity: e.quantity,
        variantId: e.variantId,
        unit: unitLabel,
        variant: {
          id: e.variantId,
          weight: unitLabel,
          price: unitPrice,
        },
        product: {
          id: String(p.id),
          name: p.name,
          price: unitPrice,
          display_price: unitPrice,
          base_price_per_kg: Number(p.base_price_per_kg || 0) || null,
          unit: unitLabel || p.unit || '',
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
  const { productId, quantity, variantId, weightGrams } = req.validated.body;
  const pid = Number(productId);
  const qty = Number(quantity);

  if (!pid || Number.isNaN(pid) || pid <= 0) return fail(res, 400, 'Invalid productId');
  if (!qty || qty < 1 || qty > 10) return fail(res, 400, 'Quantity must be 1-10');

  const stockCheck = await checkStock(pid, qty);
  if (!stockCheck.valid) return fail(res, 400, stockCheck.message);

  const map = await readCartMap(userId);
  const current = normalizeCartEntry(map[productId]);
  const newQty = current.quantity + qty;

  map[productId] = {
    quantity: newQty,
    variantId: variantId || current.variantId || null,
    weightGrams:
      weightGrams != null
        ? Number(weightGrams)
        : current.weightGrams || gramsFromVariantId(variantId) || null,
  };
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
    const current = normalizeCartEntry(map[productId]);
    const { variantId, weightGrams } = req.validated.body;
    map[productId] = {
      quantity: qty,
      variantId: variantId || current.variantId || null,
      weightGrams:
        weightGrams != null
          ? Number(weightGrams)
          : current.weightGrams || gramsFromVariantId(variantId) || null,
    };
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
  const entries = Object.entries(map || {}).filter(([_, raw]) => {
    const entry = normalizeCartEntry(raw);
    return entry.quantity > 0;
  });
  return ok(res, { count: entries.length });
});

module.exports = { getCart, addToCart, updateCartItem, removeFromCart, clearCart, getCartCount };
