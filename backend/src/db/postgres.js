const { Pool } = require('pg');
const { logger } = require('../utils/logger');

// Use separate environment variables to avoid DATABASE_URL parsing issues
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'meatvo',
  // You can also pass PG* env vars (PGHOST/PGUSER/PGPASSWORD/PGDATABASE/PGPORT).
  // connectionString takes precedence when set.
  max: Number(process.env.PG_POOL_MAX || 10),
  idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 30_000),
  connectionTimeoutMillis: Number(process.env.PG_CONN_TIMEOUT_MS || 10_000),
});

logger.debug('postgres_pool_configured', {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  database: process.env.DB_NAME || 'meatvo'
});

pool.on('error', (err) => {
  logger.error('postgres_pool_error', { message: err.message, code: err.code });
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

module.exports = {
  pool,
  query,
  getClient: () => pool.connect(),
  withClient,
  withTransaction,
};

