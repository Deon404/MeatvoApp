const { Pool } = require('pg');
const { logger } = require('../utils/logger');

const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';

if (isProd && !process.env.DB_PASSWORD) {
  logger.error('missing_db_password', {
    message: 'DB_PASSWORD environment variable is not set. Refusing to start with default credentials in production.',
  });
  process.exit(1);
}

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'meatvo',
  max: Number(process.env.PG_POOL_MAX || 10),
  idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 30_000),
  connectionTimeoutMillis: Number(process.env.PG_CONN_TIMEOUT_MS || 10_000),
};

const pool = new Pool(dbConfig);

logger.debug('postgres_pool_configured', {
  host: dbConfig.host,
  port: dbConfig.port,
  user: dbConfig.user,
  database: dbConfig.database,
});

// Test connection on startup and log result clearly
pool.connect((err, client, release) => {
  if (err) {
    logger.error('postgres_connect_failed', {
      message: err.message,
      code: err.code,
      host: dbConfig.host,
      port: dbConfig.port,
      database: dbConfig.database,
    });
    console.error(`[DB] Connection FAILED — ${err.message} (host=${dbConfig.host}:${dbConfig.port} db=${dbConfig.database})`);
  } else {
    release();
    logger.info('postgres_connected', {
      host: dbConfig.host,
      port: dbConfig.port,
      database: dbConfig.database,
    });
    console.log(`[DB] Database connected (host=${dbConfig.host}:${dbConfig.port} db=${dbConfig.database})`);
  }
});

pool.on('error', (err) => {
  logger.error('postgres_pool_error', { message: err.message, code: err.code });
  console.error(`[DB] Pool error — ${err.message}`);
});

const query = (text, params) => pool.query(text, params);

const withClient = async (fn) => {
  const client = await pool.connect();
  try {
    return await fn(client);
  } finally {
    client.release();
  }
};

const withTransaction = async (fn) =>
  withClient(async (client) => {
    await client.query('BEGIN');
    try {
      const result = await fn(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('postgres_rollback_error', {
          message: rollbackErr.message,
          code: rollbackErr.code,
        });
      }
      throw err;
    }
  });

pool.transaction = withTransaction;

module.exports = {
  pool,
  query,
  getClient: () => pool.connect(),
  withClient,
  withTransaction,
};

