const Redis = require('ioredis');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const allowFallback =
  String(process.env.REDIS_ALLOW_FALLBACK || '').toLowerCase() === 'true' ||
  String(process.env.NODE_ENV || '').toLowerCase() !== 'production';

class MemoryRedis {
  constructor() {
    this.store = new Map(); // key -> { value: string, expiresAt: number|null }
    this.counters = new Map(); // key -> number
  }

  _now() {
    return Date.now();
  }

  _getEntry(key) {
    const entry = this.store.get(key);
    if (!entry) return null;
    if (entry.expiresAt && entry.expiresAt <= this._now()) {
      this.store.delete(key);
      this.counters.delete(key);
      return null;
    }
    return entry;
  }

  async get(key) {
    const entry = this._getEntry(key);
    return entry ? entry.value : null;
  }

  async set(key, value, ...args) {
    const prev = this._getEntry(key);
    let expiresAt = prev ? prev.expiresAt : null;

    // Supports: set key val 'EX' seconds
    // Supports: set key val 'KEEPTTL'
    if (args && args.length >= 2 && String(args[0]).toUpperCase() === 'EX') {
      const seconds = Number(args[1]);
      if (!Number.isNaN(seconds) && seconds > 0) expiresAt = this._now() + seconds * 1000;
    } else if (args && args.length >= 1 && String(args[0]).toUpperCase() === 'KEEPTTL') {
      // keep existing expiresAt - do nothing
      if (!expiresAt) {
        // If no expiry exists, set a default expiry
        expiresAt = this._now() + 300000; // 5 minutes default
      }
    } else if (!prev) {
      expiresAt = null;
    }

    this.store.set(key, { value: String(value), expiresAt });
    return 'OK';
  }

  async del(key) {
    this.store.delete(key);
    this.counters.delete(key);
    return 1;
  }

  async incr(key) {
    // Respect expiry if present via store (rate limiter uses incr + expire separately)
    const entry = this._getEntry(key);
    if (!entry) {
      this.store.set(key, { value: '0', expiresAt: null });
      this.counters.delete(key);
    }
    const cur = this.counters.get(key) || 0;
    const next = cur + 1;
    this.counters.set(key, next);
    return next;
  }

  async expire(key, seconds) {
    const entry = this._getEntry(key);
    if (!entry) return 0;
    const s = Number(seconds);
    if (Number.isNaN(s) || s <= 0) return 0;
    entry.expiresAt = this._now() + s * 1000;
    this.store.set(key, entry);
    return 1;
  }

  async sadd(key, member) {
    const entry = this._getEntry(key);
    if (!entry) {
      this.store.set(key, { value: JSON.stringify([member]), expiresAt: null });
      this.counters.delete(key);
      return 1;
    }
    const members = JSON.parse(entry.value || '[]');
    if (!members.includes(member)) {
      members.push(member);
      this.store.set(key, { value: JSON.stringify(members), expiresAt: entry.expiresAt });
    }
    return 1;
  }

  async scard(key) {
    const entry = this._getEntry(key);
    if (!entry) return 0;
    const members = JSON.parse(entry.value || '[]');
    return members.length;
  }
}

const memory = new MemoryRedis();

const client = new Redis(REDIS_URL, {
  lazyConnect: true,
  enableOfflineQueue: false,
});

let loggedRedisError = false;
let redisReady = false;

client.on('connect', () => {
  redisReady = true;
  loggedRedisError = false;
  console.log('Redis connected');
});

client.on('end', () => {
  redisReady = false;
});

client.on('error', (err) => {
  redisReady = false;
  if (!allowFallback) {
    console.error('Redis connection error:', err);
    return;
  }
  // Avoid flooding the console on retry loops.
  if (!loggedRedisError) {
    loggedRedisError = true;
    console.warn('Redis unavailable; falling back to in-memory store for this process.');
  }
});

// Kick off connection in background (don’t block server startup).
client.connect().catch(() => {});

const withFallback = (fnName) =>
  async (...args) => {
    if (redisReady) return client[fnName](...args);
    if (!allowFallback) return client[fnName](...args); // will throw; surface error
    return memory[fnName](...args);
  };

module.exports = {
  get: withFallback('get'),
  set: withFallback('set'),
  del: withFallback('del'),
  incr: withFallback('incr'),
  expire: withFallback('expire'),
  sadd: withFallback('sadd'),
  scard: withFallback('scard'),
};
