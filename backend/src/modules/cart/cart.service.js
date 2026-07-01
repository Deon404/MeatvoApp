const redis = require('../../db/redis');

const cartKey = (userId) => `cart:user:${userId}`;

const normalizeCartEntry = (raw) => {
  if (typeof raw === 'number') {
    return { quantity: raw, weightGrams: null, variantId: null };
  }
  if (raw && typeof raw === 'object') {
    return {
      quantity: Number(raw.quantity || 0),
      weightGrams:
        raw.weightGrams != null && Number.isFinite(Number(raw.weightGrams))
          ? Number(raw.weightGrams)
          : null,
      variantId: raw.variantId ? String(raw.variantId) : null,
    };
  }
  return { quantity: 0, weightGrams: null, variantId: null };
};

const gramsFromVariantId = (variantId) => {
  if (!variantId) return null;
  const match = String(variantId).match(/_(\d+)$/);
  if (!match) return null;
  const grams = Number(match[1]);
  return Number.isFinite(grams) && grams > 0 ? grams : null;
};

const readCartMap = async (userId) => {
  const raw = await redis.get(cartKey(userId));
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
};

const writeCartMap = async (userId, map) => {
  await redis.set(cartKey(userId), JSON.stringify(map), 'EX', 60 * 60 * 24 * 30);
};

const clearCart = async (userId) => {
  await redis.del(cartKey(userId));
};

module.exports = {
  readCartMap,
  writeCartMap,
  clearCart,
  normalizeCartEntry,
  gramsFromVariantId,
};

