/**
 * Integration test harness for failed-delivery workflow.
 * Requires DATABASE_URL (or default local postgres from .env).
 */
require('dotenv').config();

const { query, pool } = require('../../src/db/postgres');
const { ensureSchema } = require('../../src/db/ensureSchema');
const {
  markFailedDelivery,
  confirmReturnToStore,
  resolveFailedDelivery,
} = require('../../src/services/failedDelivery.service');
const { manualAssignOrderToPartner } = require('../../src/services/assignment.service');
const { isOrderBlockedFromAssignment } = require('../../src/constants/failedDelivery.constants');

const TEST_PREFIX = `fd_${Date.now()}`;

async function seedUser({ phone, role, name }) {
  const { rows } = await query(
    `INSERT INTO users (phone, name, role)
     VALUES ($1, $2, $3)
     ON CONFLICT (phone) DO UPDATE SET name = EXCLUDED.name, role = EXCLUDED.role
     RETURNING id, phone, role`,
    [phone, name, role]
  );
  return rows[0];
}

async function seedDeliveryPartner(userId) {
  const { rows } = await query(
    `INSERT INTO delivery_partners (user_id, is_online, approved, current_lat, current_lng)
     VALUES ($1, TRUE, TRUE, 12.9716, 77.5946)
     ON CONFLICT (user_id) DO UPDATE SET is_online = TRUE, approved = TRUE
     RETURNING id, user_id`,
    [userId]
  );
  return rows[0];
}

async function seedProduct() {
  const { rows } = await query(
    `INSERT INTO products (name, price, stock, active)
     VALUES ($1, 250, 100, TRUE)
     RETURNING id`,
    [`${TEST_PREFIX}_product`]
  );
  return rows[0];
}

async function seedOrder({
  customerId,
  status = 'OUT_FOR_DELIVERY',
  paymentMode = 'COD',
}) {
  const address = JSON.stringify({
    text: 'Test Address',
    lat: 12.972,
    lng: 77.595,
  });
  const { rows } = await query(
    `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode, payment_status)
     VALUES ($1, $2, 500, $3::jsonb, $4, 'PENDING')
     RETURNING id, status, payment_status, customer_id`,
    [customerId, status, address, paymentMode]
  );
  const order = rows[0];
  const product = await seedProduct();
  await query(
    `INSERT INTO order_items (order_id, product_id, quantity, price)
     VALUES ($1, $2, 1, 500)`,
    [order.id, product.id]
  );
  return order;
}

async function seedAssignment({ orderId, partnerId, status = 'ACCEPTED' }) {
  await query(
    `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
     VALUES ($1, $2, $3)
     ON CONFLICT (order_id) DO UPDATE SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = EXCLUDED.status`,
    [orderId, partnerId, status]
  );
}

async function getOrder(orderId) {
  const { rows } = await query('SELECT * FROM orders WHERE id = $1', [orderId]);
  return rows[0];
}

async function getOpenTask(orderId) {
  const { rows } = await query(
    `SELECT * FROM admin_tasks WHERE order_id = $1 AND status = 'open'`,
    [orderId]
  );
  return rows[0];
}

async function getProductStock(productId) {
  const { rows } = await query('SELECT stock FROM products WHERE id = $1', [productId]);
  return Number(rows[0]?.stock || 0);
}

async function cleanupTestData(ids) {
  const { orderIds = [], userIds = [], productIds = [] } = ids;
  if (orderIds.length) {
    await query('DELETE FROM admin_tasks WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM order_assignments WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM order_items WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM orders WHERE id = ANY($1::bigint[])', [orderIds]);
  }
  if (productIds.length) {
    await query('DELETE FROM products WHERE id = ANY($1::bigint[])', [productIds]);
  }
  if (userIds.length) {
    await query('DELETE FROM delivery_partners WHERE user_id = ANY($1::bigint[])', [userIds]);
    await query('DELETE FROM users WHERE id = ANY($1::bigint[])', [userIds]);
  }
}

module.exports = {
  ensureSchema,
  query,
  pool,
  seedUser,
  seedDeliveryPartner,
  seedOrder,
  seedAssignment,
  getOrder,
  getOpenTask,
  getProductStock,
  cleanupTestData,
  markFailedDelivery,
  confirmReturnToStore,
  resolveFailedDelivery,
  manualAssignOrderToPartner,
  isOrderBlockedFromAssignment,
  TEST_PREFIX,
};
