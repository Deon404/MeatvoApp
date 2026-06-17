const Redis = require('ioredis');
const { logger } = require('./logger');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

function patternToRegex(pattern) {
  const escaped = String(pattern).replace(/[.+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`^${escaped.replace(/\*/g, '.*')}$`);
}

/**
 * Delete Redis keys matching a glob pattern (e.g. products:*).
 * Uses SCAN to avoid blocking Redis. Safe for production cache invalidation.
 */
async function deleteByPattern(pattern, { memoryStore } = {}) {
  if (!pattern || typeof pattern !== 'string') return 0;

  if (memoryStore) {
    const regex = patternToRegex(pattern);
    let deleted = 0;
    for (const key of memoryStore.keys()) {
      if (regex.test(key)) {
        memoryStore.delete(key);
        deleted += 1;
      }
    }
    return deleted;
  }

  const client = new Redis(REDIS_URL, {
    lazyConnect: true,
    enableOfflineQueue: false,
    maxRetriesPerRequest: 1,
  });

  try {
    await client.connect();
    let cursor = '0';
    let deleted = 0;

    do {
      const [nextCursor, keys] = await client.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = nextCursor;
      if (keys.length > 0) {
        await client.del(...keys);
        deleted += keys.length;
      }
    } while (cursor !== '0');

    return deleted;
  } catch (err) {
    logger.warn('redis_pattern_delete_failed', { pattern, message: err.message });
    return 0;
  } finally {
    try {
      if (client.status === 'ready' || client.status === 'connect') {
        await client.quit();
      }
    } catch (_) {
      // ignore disconnect errors
    }
  }
}

module.exports = { deleteByPattern, patternToRegex };
