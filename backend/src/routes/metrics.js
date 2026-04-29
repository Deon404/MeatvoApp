const express = require('express');
const { logger } = require('../utils/logger');
const router = express.Router();

// Prometheus metrics collection
let metrics = {
  // HTTP metrics
  httpRequestsTotal: 0,
  httpRequestDuration: [],
  httpErrorsTotal: 0,
  
  // Business metrics
  ordersCreated: 0,
  ordersCompleted: 0,
  ordersFailed: 0,
  paymentsProcessed: 0,
  paymentsFailed: 0,
  usersRegistered: 0,
  deliveryPartnersOnline: 0,
  
  // System metrics
  activeConnections: 0,
  cacheHits: 0,
  cacheMisses: 0,
  
  // Database metrics
  dbConnections: 0,
  dbQueryDuration: [],
  
  // Timestamps
  lastBackupSuccess: null,
  lastOrderCreated: null,
  lastPaymentProcessed: null
};

// Middleware to collect HTTP metrics
const collectMetrics = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    metrics.httpRequestsTotal++;
    metrics.httpRequestDuration.push(duration);
    
    // Keep only last 1000 measurements
    if (metrics.httpRequestDuration.length > 1000) {
      metrics.httpRequestDuration = metrics.httpRequestDuration.slice(-1000);
    }
    
    if (res.statusCode >= 400) {
      metrics.httpErrorsTotal++;
    }
  });
  
  next();
};

// Prometheus metrics endpoint
router.get('/', (req, res) => {
  try {
    const prometheusMetrics = [];
    
    // HTTP metrics
    prometheusMetrics.push(
      `# HELP meatvo_http_requests_total Total number of HTTP requests`,
      `# TYPE meatvo_http_requests_total counter`,
      `meatvo_http_requests_total ${metrics.httpRequestsTotal}`,
      '',
      `# HELP meatvo_http_errors_total Total number of HTTP errors`,
      `# TYPE meatvo_http_errors_total counter`,
      `meatvo_http_errors_total ${metrics.httpErrorsTotal}`,
      '',
      `# HELP meatvo_http_request_duration_seconds HTTP request duration`,
      `# TYPE meatvo_http_request_duration_seconds histogram`
    );
    
    // Calculate histogram buckets for HTTP duration
    const durationBuckets = [0.1, 0.5, 1, 2, 5, 10];
    const sortedDurations = metrics.httpRequestDuration.sort((a, b) => a - b);
    
    for (const bucket of durationBuckets) {
      const count = sortedDurations.filter(d => d <= bucket * 1000).length;
      prometheusMetrics.push(`meatvo_http_request_duration_seconds_bucket{le="${bucket}"} ${count}`);
    }
    prometheusMetrics.push(`meatvo_http_request_duration_seconds_bucket{le="+Inf"} ${sortedDurations.length}`);
    
    // Business metrics
    prometheusMetrics.push(
      '',
      `# HELP meatvo_orders_created_total Total number of orders created`,
      `# TYPE meatvo_orders_created_total counter`,
      `meatvo_orders_created_total ${metrics.ordersCreated}`,
      '',
      `# HELP meatvo_orders_completed_total Total number of orders completed`,
      `# TYPE meatvo_orders_completed_total counter`,
      `meatvo_orders_completed_total ${metrics.ordersCompleted}`,
      '',
      `# HELP meatvo_orders_failed_total Total number of orders failed`,
      `# TYPE meatvo_orders_failed_total counter`,
      `meatvo_orders_failed_total ${metrics.ordersFailed}`,
      '',
      `# HELP meatvo_payments_processed_total Total number of payments processed`,
      `# TYPE meatvo_payments_processed_total counter`,
      `meatvo_payments_processed_total ${metrics.paymentsProcessed}`,
      '',
      `# HELP meatvo_payments_failed_total Total number of payments failed`,
      `# TYPE meatvo_payments_failed_total counter`,
      `meatvo_payments_failed_total ${metrics.paymentsFailed}`,
      '',
      `# HELP meatvo_users_registered_total Total number of users registered`,
      `# TYPE meatvo_users_registered_total counter`,
      `meatvo_users_registered_total ${metrics.usersRegistered}`,
      '',
      `# HELP meatvo_delivery_partners_online Current number of delivery partners online`,
      `# TYPE meatvo_delivery_partners_online gauge`,
      `meatvo_delivery_partners_online ${metrics.deliveryPartnersOnline}`
    );
    
    // System metrics
    prometheusMetrics.push(
      '',
      `# HELP meatvo_active_connections Current number of active connections`,
      `# TYPE meatvo_active_connections gauge`,
      `meatvo_active_connections ${metrics.activeConnections}`,
      '',
      `# HELP meatvo_cache_hits_total Total number of cache hits`,
      `# TYPE meatvo_cache_hits_total counter`,
      `meatvo_cache_hits_total ${metrics.cacheHits}`,
      '',
      `# HELP meatvo_cache_misses_total Total number of cache misses`,
      `# TYPE meatvo_cache_misses_total counter`,
      `meatvo_cache_misses_total ${metrics.cacheMisses}`
    );
    
    // Database metrics
    prometheusMetrics.push(
      '',
      `# HELP meatvo_db_connections Current number of database connections`,
      `# TYPE meatvo_db_connections gauge`,
      `meatvo_db_connections ${metrics.dbConnections}`,
      '',
      `# HELP meatvo_db_query_duration_seconds Database query duration`,
      `# TYPE meatvo_db_query_duration_seconds histogram`
    );
    
    // Calculate histogram buckets for DB query duration
    const queryBuckets = [0.01, 0.05, 0.1, 0.5, 1, 2];
    const sortedQueries = metrics.dbQueryDuration.sort((a, b) => a - b);
    
    for (const bucket of queryBuckets) {
      const count = sortedQueries.filter(d => d <= bucket * 1000).length;
      prometheusMetrics.push(`meatvo_db_query_duration_seconds_bucket{le="${bucket}"} ${count}`);
    }
    prometheusMetrics.push(`meatvo_db_query_duration_seconds_bucket{le="+Inf"} ${sortedQueries.length}`);
    
    // Timestamp metrics
    prometheusMetrics.push(
      '',
      `# HELP meatvo_last_backup_success_timestamp Unix timestamp of last successful backup`,
      `# TYPE meatvo_last_backup_success_timestamp gauge`,
      `meatvo_last_backup_success_timestamp ${metrics.lastBackupSuccess || 0}`,
      '',
      `# HELP meatvo_last_order_created_timestamp Unix timestamp of last order created`,
      `# TYPE meatvo_last_order_created_timestamp gauge`,
      `meatvo_last_order_created_timestamp ${metrics.lastOrderCreated || 0}`,
      '',
      `# HELP meatvo_last_payment_processed_timestamp Unix timestamp of last payment processed`,
      `# TYPE meatvo_last_payment_processed_timestamp gauge`,
      `meatvo_last_payment_processed_timestamp ${metrics.lastPaymentProcessed || 0}`
    );
    
    // Node.js metrics
    const memUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    
    prometheusMetrics.push(
      '',
      `# HELP nodejs_memory_usage_bytes Node.js memory usage in bytes`,
      `# TYPE nodejs_memory_usage_bytes gauge`,
      `nodejs_memory_usage_bytes{type="rss"} ${memUsage.rss}`,
      `nodejs_memory_usage_bytes{type="heapTotal"} ${memUsage.heapTotal}`,
      `nodejs_memory_usage_bytes{type="heapUsed"} ${memUsage.heapUsed}`,
      `nodejs_memory_usage_bytes{type="external"} ${memUsage.external}`,
      '',
      `# HELP nodejs_uptime_seconds Node.js uptime in seconds`,
      `# TYPE nodejs_uptime_seconds gauge`,
      `nodejs_uptime_seconds ${process.uptime()}`,
      '',
      `# HELP nodejs_cpu_usage_total Node.js CPU usage`,
      `# TYPE nodejs_cpu_usage_total gauge`,
      `nodejs_cpu_usage_total{type="user"} ${cpuUsage.user}`,
      `nodejs_cpu_usage_total{type="system"} ${cpuUsage.system}`
    );
    
    res.set('Content-Type', 'text/plain');
    res.send(prometheusMetrics.join('\n'));
  } catch (error) {
    logger.error('metrics_endpoint_error', { error: error.message });
    res.status(500).send('Error generating metrics');
  }
});

// Business metrics endpoints
router.post('/business/order-created', (req, res) => {
  metrics.ordersCreated++;
  metrics.lastOrderCreated = Date.now();
  logger.info('order_created_metric', { total: metrics.ordersCreated });
  res.json({ status: 'recorded' });
});

router.post('/business/order-completed', (req, res) => {
  metrics.ordersCompleted++;
  logger.info('order_completed_metric', { total: metrics.ordersCompleted });
  res.json({ status: 'recorded' });
});

router.post('/business/order-failed', (req, res) => {
  metrics.ordersFailed++;
  logger.info('order_failed_metric', { total: metrics.ordersFailed });
  res.json({ status: 'recorded' });
});

router.post('/business/payment-processed', (req, res) => {
  metrics.paymentsProcessed++;
  metrics.lastPaymentProcessed = Date.now();
  logger.info('payment_processed_metric', { total: metrics.paymentsProcessed });
  res.json({ status: 'recorded' });
});

router.post('/business/payment-failed', (req, res) => {
  metrics.paymentsFailed++;
  logger.info('payment_failed_metric', { total: metrics.paymentsFailed });
  res.json({ status: 'recorded' });
});

router.post('/business/user-registered', (req, res) => {
  metrics.usersRegistered++;
  logger.info('user_registered_metric', { total: metrics.usersRegistered });
  res.json({ status: 'recorded' });
});

router.post('/business/delivery-partners-online', (req, res) => {
  const { count } = req.body;
  metrics.deliveryPartnersOnline = count;
  logger.info('delivery_partners_online_metric', { count });
  res.json({ status: 'recorded' });
});

// System metrics endpoints
router.post('/system/active-connections', (req, res) => {
  const { count } = req.body;
  metrics.activeConnections = count;
  res.json({ status: 'recorded' });
});

router.post('/system/cache-hit', (req, res) => {
  metrics.cacheHits++;
  res.json({ status: 'recorded' });
});

router.post('/system/cache-miss', (req, res) => {
  metrics.cacheMisses++;
  res.json({ status: 'recorded' });
});

router.post('/system/db-connection', (req, res) => {
  const { count } = req.body;
  metrics.dbConnections = count;
  res.json({ status: 'recorded' });
});

router.post('/system/db-query-duration', (req, res) => {
  const { duration } = req.body;
  metrics.dbQueryDuration.push(duration);
  
  // Keep only last 1000 measurements
  if (metrics.dbQueryDuration.length > 1000) {
    metrics.dbQueryDuration = metrics.dbQueryDuration.slice(-1000);
  }
  
  res.json({ status: 'recorded' });
});

// Backup metrics
router.post('/backup/success', (req, res) => {
  metrics.lastBackupSuccess = Date.now();
  logger.info('backup_success_metric', { timestamp: metrics.lastBackupSuccess });
  res.json({ status: 'recorded' });
});

// Reset metrics (for testing)
router.post('/reset', (req, res) => {
  if (process.env.NODE_ENV !== 'development') {
    return res.status(403).json({ error: 'Metrics reset not allowed in production' });
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
    lastPaymentProcessed: null
  };
  
  logger.info('metrics_reset');
  res.json({ status: 'reset' });
});

// Get current metrics as JSON
router.get('/json', (req, res) => {
  res.json(metrics);
});

module.exports = { router, collectMetrics };
