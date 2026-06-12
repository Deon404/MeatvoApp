const HEALTH_STATUS = {
  HEALTHY: 'healthy',
  DEGRADED: 'degraded',
  UNHEALTHY: 'unhealthy',
  READY: 'ready',
  ALIVE: 'alive',
};

const PROBE_PATHS = ['/ready', '/live'];

const CHECK_NAMES = {
  DATABASE: 'database',
  REDIS: 'redis',
  MEMORY: 'memory',
  DISK: 'disk',
};

module.exports = { HEALTH_STATUS, PROBE_PATHS, CHECK_NAMES };
