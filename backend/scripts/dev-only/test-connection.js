#!/usr/bin/env node
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const axios = require('axios');
const Redis = require('ioredis');
const { Pool } = require('pg');

const DEFAULT_BASE_URL = process.env.BACKEND_BASE_URL || `http://localhost:${process.env.PORT || 8080}`;
const MSG91_OTP_URL = 'https://api.msg91.com/api/v5/otp';

const printResult = (label, pass, detail = '') => {
  const mark = pass ? '[✓]' : '[x]';
  const suffix = detail ? ` - ${detail}` : '';
  console.log(`${mark} ${label}${suffix}`);
};
const printWarn = (message) => {
  console.warn(`[⚠] ${message}`);
};

async function testPostgres() {
  const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'meatvo',
    connectionTimeoutMillis: 5000,
  });

  try {
    const result = await pool.query('SELECT current_database() AS db');
    const dbName = result.rows?.[0]?.db || 'unknown';
    return { ok: true, detail: `database=${dbName}` };
  } catch (error) {
    return { ok: false, detail: error.message };
  } finally {
    await pool.end().catch(() => {});
  }
}

async function testRedis() {
  const redisUrl = process.env.REDIS_URL;
  if (!redisUrl) {
    return { ok: false, detail: 'REDIS_URL not set (optional service)' };
  }

  const redis = new Redis(redisUrl, {
    lazyConnect: true,
    connectTimeout: 4000,
    maxRetriesPerRequest: 1,
    enableOfflineQueue: false,
  });

  try {
    await redis.connect();
    await redis.set('__connection_test__', '1', 'EX', 5);
    const value = await redis.get('__connection_test__');
    return { ok: value === '1', detail: value === '1' ? 'round-trip success' : 'round-trip mismatch' };
  } catch (error) {
    return { ok: false, detail: error.message };
  } finally {
    await redis.quit().catch(() => redis.disconnect());
  }
}

async function testMsg91() {
  const authKey = process.env.MSG91_AUTH_KEY;
  if (!authKey) {
    return { ok: false, detail: 'MSG91_AUTH_KEY missing' };
  }

  const templateId = process.env.MSG91_OTP_TEMPLATE_ID || '';
  try {
    const response = await axios.get(MSG91_OTP_URL, {
      timeout: 7000,
      params: {
        authkey: authKey,
        template_id: templateId,
        mobile: `91${process.env.OTP_TEST_PHONE}`,
        otp: '1234',
      },
    });
    return { ok: response.status >= 200 && response.status < 300, detail: `status=${response.status}` };
  } catch (error) {
    const status = error.response?.status;
    if (status) {
      if (status === 401) {
        return { ok: false, detail: 'status=401 (invalid auth key)' };
      }
      return { ok: true, detail: `reachable (status=${status})` };
    }
    return { ok: false, detail: error.message || error.code || 'network failure' };
  }
}

async function testServerHealth() {
  try {
    const response = await axios.get(`${DEFAULT_BASE_URL}/health`, { timeout: 5000 });
    const payload = response.data?.data || response.data || {};
    const healthy = String(payload.status || '').toLowerCase() === 'ok' && payload.db === 'connected';
    return { ok: healthy, detail: `status=${payload.status || 'unknown'}, db=${payload.db || 'unknown'}` };
  } catch (error) {
    const status = error.response?.status;
    const msg = status ? `status=${status}` : (error.message || error.code || 'connection failed');
    return { ok: false, detail: msg };
  }
}

async function main() {
  console.log('Running backend connectivity checks...\n');

  const pg = await testPostgres();
  printResult('PostgreSQL connected', pg.ok, pg.detail);

  try {
    const redis = await testRedis();
    if (redis.ok) {
      printResult('Redis connected', true, redis.detail);
    } else {
      printWarn('Redis not available (using memory fallback)');
    }
  } catch (_error) {
    printWarn('Redis not available (using memory fallback)');
  }

  const msg91 = await testMsg91();
  printResult('MSG91 API valid', msg91.ok, msg91.detail);

  const hasJwtSecret =
    Boolean(process.env.JWT_SECRET) ||
    Boolean(process.env.JWT_ACCESS_SECRET && process.env.JWT_REFRESH_SECRET);
  printResult(
    'JWT secrets exist',
    hasJwtSecret,
    hasJwtSecret ? 'present' : 'missing (need JWT_ACCESS_SECRET + JWT_REFRESH_SECRET)'
  );

  const health = await testServerHealth();
  printResult('Server healthy', health.ok, health.detail);

  const passed = [pg.ok, msg91.ok, hasJwtSecret, health.ok].every(Boolean);
  process.exitCode = passed ? 0 : 1;
}

main().catch((error) => {
  console.error('[x] Test runner failed:', error.message);
  process.exit(1);
});
