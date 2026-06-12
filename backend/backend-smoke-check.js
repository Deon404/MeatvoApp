require('dotenv').config();
const { logger } = require('./src/utils/logger');

const BASE_URL = process.env.BACKEND_TEST_BASE_URL || `http://localhost:${process.env.PORT || 8080}`;

async function getJson(path) {
  const response = await fetch(`${BASE_URL}${path}`);
  const json = await response.json().catch(() => ({}));
  return { response, json };
}

async function run() {
  logger.info(`Backend smoke check started on ${BASE_URL}`);

  const health = await getJson('/health');
  if (!health.response.ok || health.json?.status !== 'ok' || health.json?.db !== 'connected') {
    throw new Error(
      `Health check failed (${health.response.status}): ${JSON.stringify(health.json)}`
    );
  }
  logger.info('Health check passed.');

  const categories = await getJson('/api/v1/categories');
  if (!categories.response.ok) {
    throw new Error(`Categories check failed (${categories.response.status})`);
  }
  logger.info('Categories endpoint passed.');

  const products = await getJson('/api/v1/products?limit=1');
  if (!products.response.ok) {
    throw new Error(`Products check failed (${products.response.status})`);
  }
  logger.info('Products endpoint passed.');

  logger.info('Backend smoke check completed successfully.');
}

run().catch((error) => {
  logger.error(`Backend smoke check failed: ${error.message}`);
  process.exit(1);
});
