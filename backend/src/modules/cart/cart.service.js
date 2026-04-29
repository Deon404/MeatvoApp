const redis = require('../../db/redis');

const cartKey = (userId) => `cart:user:${userId}`;

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

module.exports = { readCartMap, writeCartMap, clearCart };

