const express = require('express');
const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { elasticsearchLogger } = require('../utils/elasticsearchLogger');
const router = express.Router();

// Basic health check
router.get('/', async (req, res) => {
  try {
    const timestamp = new Date().toISOString();
    const uptime = process.uptime();
    const memory = process.memoryUsage();
    
    res.json({
      status: 'healthy',
      timestamp,
      uptime: Math.floor(uptime),
      uptimeHuman: formatUptime(uptime),
      memory: {
        rss: Math.round(memory.rss / 1024 / 1024), // MB
        heapTotal: Math.round(memory.heapTotal / 1024 / 1024), // MB
        heapUsed: Math.round(memory.heapUsed / 1024 / 1024), // MB
        external: Math.round(memory.external / 1024 / 1024) // MB
      },
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development'
    });
  } catch (error) {
    logger.error('health_check_failed', { error: error.message });
    res.status(500).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Database health check
router.get('/db', async (req, res) => {
  try {
    const start = Date.now();
    const result = await query('SELECT 1 as health_check, NOW() as timestamp');
    const responseTime = Date.now() - start;
    
    // Check connection pool stats if available
    let poolStats = null;
    try {
      const poolResult = await query(`
        SELECT 
          count(*) as total_connections,
          count(*) FILTER (WHERE state = 'active') as active_connections,
          count(*) FILTER (WHERE state = 'idle') as idle_connections
        FROM pg_stat_activity 
        WHERE datname = current_database()
      `);
      poolStats = poolResult[0];
    } catch (poolError) {
      logger.warn('pool_stats_failed', { error: poolError.message });
    }
    
    res.json({
      status: 'healthy',
      database: 'postgresql',
      responseTime: `${responseTime}ms`,
      timestamp: result[0].timestamp,
      poolStats
    });
  } catch (error) {
    logger.error('database_health_check_failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      database: 'postgresql',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Redis health check
router.get('/redis', async (req, res) => {
  try {
    const redis = require('../db/redis');
    const start = Date.now();
    
    // Test Redis connection
    const pong = await redis.ping();
    const responseTime = Date.now() - start;
    
    // Get Redis info
    const info = await redis.info('memory');
    const memoryInfo = parseRedisInfo(info);
    
    res.json({
      status: 'healthy',
      redis: 'connected',
      responseTime: `${responseTime}ms`,
      pong,
      memory: {
        used: Math.round(memoryInfo.used_memory / 1024 / 1024), // MB
        peak: Math.round(memoryInfo.used_memory_peak / 1024 / 1024), // MB
        rss: Math.round(memoryInfo.used_memory_rss / 1024 / 1024) // MB
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('redis_health_check_failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      redis: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Elasticsearch health check
router.get('/elasticsearch', async (req, res) => {
  try {
    const start = Date.now();
    
    // Check Elasticsearch cluster health
    const health = await elasticsearchLogger.client.cluster.health();
    const responseTime = Date.now() - start;
    
    res.json({
      status: health.status === 'green' ? 'healthy' : 'degraded',
      elasticsearch: 'connected',
      responseTime: `${responseTime}ms`,
      cluster: {
        status: health.status,
        nodes: health.number_of_nodes,
        data_nodes: health.number_of_data_nodes,
        active_shards: health.active_shards,
        relocating_shards: health.relocating_shards,
        initializing_shards: health.initializing_shards,
        unassigned_shards: health.unassigned_shards
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('elasticsearch_health_check_failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      elasticsearch: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// External services health check
router.get('/external', async (req, res) => {
  const services = {};
  const start = Date.now();
  
  // Check MSG91
  try {
    const axios = require('axios');
    const msg91Response = await axios.get('https://api.msg91.com/api/v5/health', {
      timeout: 5000,
      headers: {
        'authkey': process.env.MSG91_API_KEY
      }
    });
    services.msg91 = {
      status: 'healthy',
      responseTime: `${Date.now() - start}ms`
    };
  } catch (error) {
    services.msg91 = {
      status: 'unhealthy',
      error: error.message
    };
  }
  
  // Check PhonePe
  try {
    const phonePeResponse = await axios.get('https://api.phonepe.com/health', {
      timeout: 5000
    });
    services.phonepe = {
      status: 'healthy',
      responseTime: `${Date.now() - start}ms`
    };
  } catch (error) {
    services.phonepe = {
      status: 'unhealthy',
      error: error.message
    };
  }
  
  // Check Google Maps API
  try {
    const mapsResponse = await axios.get(
      `https://maps.googleapis.com/maps/api/distancematrix/json?origins=0,0&destinations=0,0&key=${process.env.GOOGLE_MAPS_API_KEY}`,
      { timeout: 5000 }
    );
    services.googleMaps = {
      status: mapsResponse.data.status === 'OK' ? 'healthy' : 'degraded',
      responseTime: `${Date.now() - start}ms`
    };
  } catch (error) {
    services.googleMaps = {
      status: 'unhealthy',
      error: error.message
    };
  }
  
  const allHealthy = Object.values(services).every(service => service.status === 'healthy');
  
  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'healthy' : 'degraded',
    services,
    timestamp: new Date().toISOString()
  });
});

// Comprehensive health check (all services)
router.get('/comprehensive', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    services: {}
  };
  
  const checks = [
    { name: 'database', path: '/health/db' },
    { name: 'redis', path: '/health/redis' },
    { name: 'elasticsearch', path: '/health/elasticsearch' },
    { name: 'external', path: '/health/external' }
  ];
  
  for (const check of checks) {
    try {
      const response = await req.app.locals.request(check.path);
      health.services[check.name] = {
        status: response.body.status,
        ...response.body
      };
    } catch (error) {
      health.services[check.name] = {
        status: 'unhealthy',
        error: error.message
      };
    }
  }
  
  // Determine overall status
  const unhealthyServices = Object.entries(health.services)
    .filter(([_, service]) => service.status === 'unhealthy');
  
  if (unhealthyServices.length > 0) {
    health.status = 'unhealthy';
    health.issues = unhealthyServices.map(([name, service]) => ({
      service: name,
      error: service.error
    }));
  } else {
    const degradedServices = Object.entries(health.services)
      .filter(([_, service]) => service.status === 'degraded');
    
    if (degradedServices.length > 0) {
      health.status = 'degraded';
      health.warnings = degradedServices.map(([name, service]) => ({
        service: name,
        warning: service.warning || 'Service is degraded'
      }));
    }
  }
  
  const statusCode = health.status === 'healthy' ? 200 : 
                    health.status === 'degraded' ? 200 : 503;
  
  res.status(statusCode).json(health);
});

// Readiness probe (for Kubernetes)
router.get('/ready', async (req, res) => {
  try {
    // Check critical dependencies
    await query('SELECT 1');
    const redis = require('../db/redis');
    await redis.ping();
    
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('readiness_probe_failed', { error: error.message });
    res.status(503).json({
      status: 'not ready',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Liveness probe (for Kubernetes)
router.get('/live', async (req, res) => {
  try {
    // Simple check if the process is responsive
    const uptime = process.uptime();
    
    res.json({
      status: 'alive',
      uptime: Math.floor(uptime),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('liveness_probe_failed', { error: error.message });
    res.status(503).json({
      status: 'not alive',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Utility functions
function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  
  return `${days}d ${hours}h ${minutes}m ${secs}s`;
}

function parseRedisInfo(info) {
  const lines = info.split('\r\n');
  const result = {};
  
  for (const line of lines) {
    if (line && !line.startsWith('#')) {
      const [key, value] = line.split(':');
      if (key && value) {
        result[key] = isNaN(value) ? value : Number(value);
      }
    }
  }
  
  return result;
}

module.exports = router;
