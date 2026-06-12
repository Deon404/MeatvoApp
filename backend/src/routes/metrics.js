// NOTE:
// This route intentionally does NOT always use the standard API envelope.
// GET / returns Prometheus text/plain exposition format (text/plain; version=0.0.4).
// Prometheus scrapers parse raw text — wrapping in JSON would break scraping entirely.
// All other endpoints (business events, system counters, reset, JSON snapshot) use
// ok() / fail() from response.js so client code gets the standard envelope.

const express = require('express');
const { logger } = require('../utils/logger');
const { ok, fail } = require('../utils/response');
const { adminOnly } = require('../middlewares/adminOnlyIp.middleware');
const router = express.Router();

router.use(adminOnly);

let metrics = {
  // HTTP
  httpRequestsTotal: 0,
  httpRequestDuration: [],
  httpErrorsTotal: 0,

  // Business
  ordersCreated: 0,
  ordersCompleted: 0,
  ordersFailed: 0,
  paymentsProcessed: 0,
  paymentsFailed: 0,
  usersRegistered: 0,
  deliveryPartnersOnline: 0,

  // System
  activeConnections: 0,
  cacheHits: 0,
  cacheMisses: 0,

  // Database
  dbConnections: 0,
  dbQueryDuration: [],

  // Timestamps
  lastBackupSuccess: null,
  lastOrderCreated: null,
  lastPaymentProcessed: null,
};

// Middleware to collect HTTP metrics — attach to app in index.js if desired
const collectMetrics = (req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    metrics.httpRequestsTotal++;
    metrics.httpRequestDuration.push(duration);
    if (metrics.httpRequestDuration.length > 1000) {
      metrics.httpRequestDuration = metrics.httpRequestDuration.slice(-1000);
    }
    if (res.statusCode >= 400) metrics.httpErrorsTotal++;
  });
  next();
};

// ─── Prometheus scrape endpoint ───────────────────────────────────────────────
// NOTE: Raw text/plain — Prometheus exposition format. DO NOT wrap in JSON.
router.get('/', (req, res) => {
  try {
    const lines = [];

    const counter = (name, help, value) => {
      lines.push(`# HELP ${name} ${help}`, `# TYPE ${name} counter`, `${name} ${value}`, '');
    };
    const gauge = (name, help, value) => {
      lines.push(`# HELP ${name} ${help}`, `# TYPE ${name} gauge`, `${name} ${value}`, '');
    };
    const histogram = (name, help, durations, buckets) => {
      lines.push(`# HELP ${name} ${help}`, `# TYPE ${name} histogram`);
      const sorted = [...durations].sort((a, b) => a - b);
      for (const le of buckets) {
        lines.push(`${name}_bucket{le="${le}"} ${sorted.filter(d => d <= le * 1000).length}`);
      }
      lines.push(`${name}_bucket{le="+Inf"} ${sorted.length}`, '');
    };

    counter('meatvo_http_requests_total', 'Total HTTP requests', metrics.httpRequestsTotal);
    counter('meatvo_http_errors_total', 'Total HTTP errors', metrics.httpErrorsTotal);
    histogram('meatvo_http_request_duration_seconds', 'HTTP request duration', metrics.httpRequestDuration, [0.1, 0.5, 1, 2, 5, 10]);

    counter('meatvo_orders_created_total', 'Orders created', metrics.ordersCreated);
    counter('meatvo_orders_completed_total', 'Orders completed', metrics.ordersCompleted);
    counter('meatvo_orders_failed_total', 'Orders failed', metrics.ordersFailed);
    counter('meatvo_payments_processed_total', 'Payments processed', metrics.paymentsProcessed);
    counter('meatvo_payments_failed_total', 'Payments failed', metrics.paymentsFailed);
    counter('meatvo_users_registered_total', 'Users registered', metrics.usersRegistered);

    gauge('meatvo_delivery_partners_online', 'Delivery partners currently online', metrics.deliveryPartnersOnline);
    gauge('meatvo_active_connections', 'Active connections', metrics.activeConnections);
    counter('meatvo_cache_hits_total', 'Cache hits', metrics.cacheHits);
    counter('meatvo_cache_misses_total', 'Cache misses', metrics.cacheMisses);

    gauge('meatvo_db_connections', 'DB connections', metrics.dbConnections);
    histogram('meatvo_db_query_duration_seconds', 'DB query duration', metrics.dbQueryDuration, [0.01, 0.05, 0.1, 0.5, 1, 2]);

    gauge('meatvo_last_backup_success_timestamp', 'Unix timestamp of last backup', metrics.lastBackupSuccess || 0);
    gauge('meatvo_last_order_created_timestamp', 'Unix timestamp of last order', metrics.lastOrderCreated || 0);
    gauge('meatvo_last_payment_processed_timestamp', 'Unix timestamp of last payment', metrics.lastPaymentProcessed || 0);

    const mem = process.memoryUsage();
    const cpu = process.cpuUsage();
    lines.push(
      '# HELP nodejs_memory_usage_bytes Node.js memory usage',
      '# TYPE nodejs_memory_usage_bytes gauge',
      `nodejs_memory_usage_bytes{type="rss"} ${mem.rss}`,
      `nodejs_memory_usage_bytes{type="heapTotal"} ${mem.heapTotal}`,
      `nodejs_memory_usage_bytes{type="heapUsed"} ${mem.heapUsed}`,
      `nodejs_memory_usage_bytes{type="external"} ${mem.external}`,
      '',
      '# HELP nodejs_uptime_seconds Node.js uptime',
      '# TYPE nodejs_uptime_seconds gauge',
      `nodejs_uptime_seconds ${process.uptime()}`,
      '',
      '# HELP nodejs_cpu_usage_total Node.js CPU usage',
      '# TYPE nodejs_cpu_usage_total gauge',
      `nodejs_cpu_usage_total{type="user"} ${cpu.user}`,
      `nodejs_cpu_usage_total{type="system"} ${cpu.system}`,
    );

    res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    return res.send(lines.join('\n'));
  } catch (error) {
    logger.error('metrics_endpoint_error', { error: error.message });
    return res.status(500).send('# Error generating metrics\n');
  }
});
// ─────────────────────────────────────────────────────────────────────────────

// JSON snapshot of current metrics (for dashboards / internal tooling)
router.get('/json', (req, res) => {
  return ok(res, metrics, 'Current metrics snapshot');
});

// ─── Business event endpoints ─────────────────────────────────────────────────
router.post('/business/order-created', (req, res) => {
  metrics.ordersCreated++;
  metrics.lastOrderCreated = Date.now();
  logger.info('order_created_metric', { total: metrics.ordersCreated });
  return ok(res, { recorded: true, total: metrics.ordersCreated }, 'Metric recorded');
});

router.post('/business/order-completed', (req, res) => {
  metrics.ordersCompleted++;
  logger.info('order_completed_metric', { total: metrics.ordersCompleted });
  return ok(res, { recorded: true, total: metrics.ordersCompleted }, 'Metric recorded');
});

router.post('/business/order-failed', (req, res) => {
  metrics.ordersFailed++;
  logger.info('order_failed_metric', { total: metrics.ordersFailed });
  return ok(res, { recorded: true, total: metrics.ordersFailed }, 'Metric recorded');
});

router.post('/business/payment-processed', (req, res) => {
  metrics.paymentsProcessed++;
  metrics.lastPaymentProcessed = Date.now();
  logger.info('payment_processed_metric', { total: metrics.paymentsProcessed });
  return ok(res, { recorded: true, total: metrics.paymentsProcessed }, 'Metric recorded');
});

router.post('/business/payment-failed', (req, res) => {
  metrics.paymentsFailed++;
  logger.info('payment_failed_metric', { total: metrics.paymentsFailed });
  return ok(res, { recorded: true, total: metrics.paymentsFailed }, 'Metric recorded');
});

router.post('/business/user-registered', (req, res) => {
  metrics.usersRegistered++;
  logger.info('user_registered_metric', { total: metrics.usersRegistered });
  return ok(res, { recorded: true, total: metrics.usersRegistered }, 'Metric recorded');
});

router.post('/business/delivery-partners-online', (req, res) => {
  const count = Number(req.body?.count);
  if (Number.isNaN(count) || count < 0) {
    return fail(res, 400, 'count must be a non-negative number');
  }
  metrics.deliveryPartnersOnline = count;
  logger.info('delivery_partners_online_metric', { count });
  return ok(res, { recorded: true, count }, 'Metric recorded');
});

// ─── System event endpoints ───────────────────────────────────────────────────
router.post('/system/active-connections', (req, res) => {
  const count = Number(req.body?.count);
  if (Number.isNaN(count) || count < 0) {
    return fail(res, 400, 'count must be a non-negative number');
  }
  metrics.activeConnections = count;
  return ok(res, { recorded: true, count }, 'Metric recorded');
});

router.post('/system/cache-hit', (req, res) => {
  metrics.cacheHits++;
  return ok(res, { recorded: true, total: metrics.cacheHits }, 'Metric recorded');
});

router.post('/system/cache-miss', (req, res) => {
  metrics.cacheMisses++;
  return ok(res, { recorded: true, total: metrics.cacheMisses }, 'Metric recorded');
});

router.post('/system/db-connection', (req, res) => {
  const count = Number(req.body?.count);
  if (Number.isNaN(count) || count < 0) {
    return fail(res, 400, 'count must be a non-negative number');
  }
  metrics.dbConnections = count;
  return ok(res, { recorded: true, count }, 'Metric recorded');
});

router.post('/system/db-query-duration', (req, res) => {
  const duration = Number(req.body?.duration);
  if (Number.isNaN(duration) || duration < 0) {
    return fail(res, 400, 'duration must be a non-negative number');
  }
  metrics.dbQueryDuration.push(duration);
  if (metrics.dbQueryDuration.length > 1000) {
    metrics.dbQueryDuration = metrics.dbQueryDuration.slice(-1000);
  }
  return ok(res, { recorded: true }, 'Metric recorded');
});

// ─── Backup events ────────────────────────────────────────────────────────────
router.post('/backup/success', (req, res) => {
  metrics.lastBackupSuccess = Date.now();
  logger.info('backup_success_metric', { timestamp: metrics.lastBackupSuccess });
  return ok(res, { recorded: true, timestamp: metrics.lastBackupSuccess }, 'Metric recorded');
});

// Reset (development only)
router.post('/reset', (req, res) => {
  if (process.env.NODE_ENV !== 'development') {
    return fail(res, 403, 'Metrics reset not allowed outside development');
  }

  metrics = {
    httpRequestsTotal: 0,
    httpRequestDuration: [],
    httpErrorsTotal: 0,
    ordersCreated: 0,
    ordersCompleted: 0,
    ordersFailed: 0,
    paymentsProcessed: 0,
    paymentsFailed: 0,
    usersRegistered: 0,
    deliveryPartnersOnline: 0,
    activeConnections: 0,
    cacheHits: 0,
    cacheMisses: 0,
    dbConnections: 0,
    dbQueryDuration: [],
    lastBackupSuccess: null,
    lastOrderCreated: null,
    lastPaymentProcessed: null,
  };

  logger.info('metrics_reset');
  return ok(res, {}, 'Metrics reset');
});

module.exports = { router, collectMetrics };
