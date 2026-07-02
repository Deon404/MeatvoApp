// NOTE:
// This route intentionally does NOT always use the standard API envelope.
// GET /ready and GET /live are consumed by Kubernetes liveness/readiness probes
// which depend on raw HTTP status codes and a simple JSON shape — not our app envelope.
// All other endpoints use ok() / fail() from response.js.

const express = require('express');
const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { ok, fail } = require('../utils/response');
const { HEALTH_STATUS } = require('../constants/health.constants');
const { adminOnly } = require('../middlewares/adminOnlyIp.middleware');
const router = express.Router();

// ─── Kubernetes probes (no IP restriction) ────────────────────────────────────
router.get('/ready', async (req, res) => {
  try {
    await query('SELECT 1');
    return res.status(200).json({ status: HEALTH_STATUS.READY, timestamp: new Date().toISOString() });
  } catch (error) {
    logger.error('readiness_probe_failed', { error: error.message });
    return res.status(503).json({ status: 'not ready', error: error.message, timestamp: new Date().toISOString() });
  }
});

router.get('/live', (req, res) => {
  return res.status(200).json({
    status: HEALTH_STATUS.ALIVE,
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

// IP-restricted detailed health endpoints
router.get('/', adminOnly, async (req, res) => {
  try {
    const timestamp = new Date().toISOString();
    const uptime = process.uptime();
    const memory = process.memoryUsage();

    return ok(res, {
      status: HEALTH_STATUS.HEALTHY,
      timestamp,
      uptime: Math.floor(uptime),
      uptimeHuman: formatUptime(uptime),
      memory: {
        rss: Math.round(memory.rss / 1024 / 1024),
        heapTotal: Math.round(memory.heapTotal / 1024 / 1024),
        heapUsed: Math.round(memory.heapUsed / 1024 / 1024),
        external: Math.round(memory.external / 1024 / 1024),
      },
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
    }, 'Service healthy');
  } catch (error) {
    logger.error('health_check_failed', { error: error.message });
    return fail(res, 500, 'Health check failed', { status: HEALTH_STATUS.UNHEALTHY });
  }
});

// Database health check
router.get('/db', adminOnly, async (req, res) => {
  try {
    const start = Date.now();
    const result = await query('SELECT 1 AS health_check, NOW() AS ts');
    const responseTime = Date.now() - start;

    let poolStats = null;
    try {
      const poolResult = await query(`
        SELECT
          count(*)                                              AS total_connections,
          count(*) FILTER (WHERE state = 'active')             AS active_connections,
          count(*) FILTER (WHERE state = 'idle')               AS idle_connections
        FROM pg_stat_activity
        WHERE datname = current_database()
      `);
      poolStats = poolResult.rows[0] || null;
    } catch (poolError) {
      logger.warn('pool_stats_failed', { error: poolError.message });
    }

    return ok(res, {
      status: HEALTH_STATUS.HEALTHY,
      database: 'postgresql',
      responseTime: `${responseTime}ms`,
      timestamp: result.rows[0]?.ts,
      poolStats,
    }, 'Database healthy');
  } catch (error) {
    logger.error('database_health_check_failed', { error: error.message });
    return fail(res, 503, 'Database unhealthy', {
      status: HEALTH_STATUS.UNHEALTHY,
      database: 'postgresql',
    });
  }
});

// Redis health check
router.get('/redis', adminOnly, async (req, res) => {
  try {
    const redis = require('../db/redis');
    const start = Date.now();

    // Use a safe probe that works on both real Redis and the in-memory fallback
    await redis.set('__health_ping__', '1', 'EX', 5);
    const val = await redis.get('__health_ping__');
    const responseTime = Date.now() - start;

    if (val !== '1') throw new Error('Redis round-trip check failed');

    return ok(res, {
      status: HEALTH_STATUS.HEALTHY,
      redis: 'connected',
      responseTime: `${responseTime}ms`,
      timestamp: new Date().toISOString(),
    }, 'Redis healthy');
  } catch (error) {
    logger.error('redis_health_check_failed', { error: error.message });
    return fail(res, 503, 'Redis unhealthy', {
      status: HEALTH_STATUS.UNHEALTHY,
      redis: 'disconnected',
    });
  }
});

// Elasticsearch health check
router.get('/elasticsearch', adminOnly, async (req, res) => {
  try {
    const { elasticsearchLogger } = require('../utils/elasticsearchLogger');
    const start = Date.now();
    const health = await elasticsearchLogger.client.cluster.health();
    const responseTime = Date.now() - start;

    return ok(res, {
      status: health.status === 'green' ? HEALTH_STATUS.HEALTHY : HEALTH_STATUS.DEGRADED,
      elasticsearch: 'connected',
      responseTime: `${responseTime}ms`,
      cluster: {
        status: health.status,
        nodes: health.number_of_nodes,
        data_nodes: health.number_of_data_nodes,
        active_shards: health.active_shards,
        relocating_shards: health.relocating_shards,
        initializing_shards: health.initializing_shards,
        unassigned_shards: health.unassigned_shards,
      },
      timestamp: new Date().toISOString(),
    }, 'Elasticsearch reachable');
  } catch (error) {
    logger.error('elasticsearch_health_check_failed', { error: error.message });
    return fail(res, 503, 'Elasticsearch unhealthy', {
      status: HEALTH_STATUS.UNHEALTHY,
      elasticsearch: 'disconnected',
    });
  }
});

// External services health check
router.get('/external', adminOnly, async (req, res) => {
  const axios = require('axios');
  const services = {};
  const start = Date.now();

  // MSG91
  try {
    const msg91HealthUrl =
      process.env.MSG91_HEALTH_URL || 'https://control.msg91.com/api/v5/health';
    await axios.get(msg91HealthUrl, {
      timeout: 5000,
      headers: { authkey: process.env.MSG91_AUTH_KEY },
    });
    services.msg91 = { status: HEALTH_STATUS.HEALTHY, responseTime: `${Date.now() - start}ms` };
  } catch (error) {
    services.msg91 = { status: HEALTH_STATUS.UNHEALTHY, error: error.message };
  }

  // Cashfree config presence. Runtime gateway status is verified by payment APIs/webhooks.
  if (process.env.CASHFREE_APP_ID && process.env.CASHFREE_SECRET_KEY) {
    services.cashfree = { status: HEALTH_STATUS.HEALTHY, configured: true };
  } else {
    services.cashfree = { status: HEALTH_STATUS.UNHEALTHY, error: 'Cashfree credentials missing' };
  }

  // Google Maps
  try {
    const mapsRes = await axios.get(
      `https://maps.googleapis.com/maps/api/distancematrix/json?origins=0,0&destinations=0,0&key=${process.env.GOOGLE_MAPS_API_KEY}`,
      { timeout: 5000 }
    );
    services.googleMaps = {
      status: mapsRes.data.status === 'OK' ? HEALTH_STATUS.HEALTHY : HEALTH_STATUS.DEGRADED,
      responseTime: `${Date.now() - start}ms`,
    };
  } catch (error) {
    services.googleMaps = { status: HEALTH_STATUS.UNHEALTHY, error: error.message };
  }

  const allHealthy = Object.values(services).every(s => s.status === HEALTH_STATUS.HEALTHY);
  const anyUnhealthy = Object.values(services).some(s => s.status === HEALTH_STATUS.UNHEALTHY);

  if (anyUnhealthy) {
    return fail(res, 503, 'One or more external services are unhealthy', { services });
  }
  return ok(res, { services }, allHealthy ? 'All external services healthy' : 'Some services degraded');
});

// Comprehensive health check (all services)
router.get('/comprehensive', adminOnly, async (req, res) => {
  const checks = ['database', 'redis', 'elasticsearch', 'external'];
  const services = {};

  await Promise.allSettled(
    checks.map(async (name) => {
      try {
        const innerRes = await internalFetch(req, `/health/${name === 'database' ? 'db' : name}`);
        services[name] = innerRes;
      } catch (error) {
        services[name] = { status: HEALTH_STATUS.UNHEALTHY, error: error.message };
      }
    })
  );

  const unhealthyList = Object.entries(services)
    .filter(([, s]) => s.status === HEALTH_STATUS.UNHEALTHY)
    .map(([name, s]) => ({ service: name, error: s.error }));

  const degradedList = Object.entries(services)
    .filter(([, s]) => s.status === HEALTH_STATUS.DEGRADED)
    .map(([name]) => ({ service: name, warning: 'Service is degraded' }));

  if (unhealthyList.length > 0) {
    return fail(res, 503, 'One or more services unhealthy', {
      status: HEALTH_STATUS.UNHEALTHY,
      services,
      issues: unhealthyList,
    });
  }

  return ok(res, {
    status: degradedList.length > 0 ? HEALTH_STATUS.DEGRADED : HEALTH_STATUS.HEALTHY,
    services,
    ...(degradedList.length > 0 ? { warnings: degradedList } : {}),
  }, degradedList.length > 0 ? 'Some services degraded' : 'All services healthy');
});

// Utility helpers
function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  return `${d}d ${h}h ${m}m ${s}s`;
}

// Minimal internal route fetch for /comprehensive (avoids a real HTTP round-trip)
async function internalFetch(req, path) {
  return new Promise((resolve) => {
    const mockRes = {
      _body: null,
      _status: 200,
      status(code) { this._status = code; return this; },
      json(body) { this._body = body; resolve(body?.data ?? body); },
    };
    req.app._router.handle(
      Object.assign(Object.create(req), { url: path, path, method: 'GET' }),
      mockRes,
      () => resolve({ status: 'unknown' })
    );
  });
}

module.exports = router;
