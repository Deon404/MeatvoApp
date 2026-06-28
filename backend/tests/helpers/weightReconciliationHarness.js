/**
 * Integration test harness for packing weight reconciliation.
 */
require('dotenv').config();

const { query, pool } = require('../../src/db/postgres');
const { ensureSchema } = require('../../src/db/ensureSchema');
const {
  packOrderWithWeightReconciliation,
  executePackingWeightReconciliation,
} = require('../../src/services/packingWeightReconciliation.service');
const { assignOrderToPartner } = require('../../src/services/assignment.service');
const { WEIGHT_ACTION } = require('../../src/constants/weightReconciliation.constants');

const TEST_PREFIX = `wr_${Date.now()}`;

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

async function seedWeightProduct({
  name,
  basePricePerKg = 500,
  weightVariants = [500, 1000],
  stock = 10,
  unit = 'kg',
}) {
  const { rows } = await query(
    `INSERT INTO products (name, price, base_price_per_kg, weight_variants, stock, unit, active)
     VALUES ($1, $2, $3, $4::integer[], $5, $6, TRUE)
     RETURNING id, name, stock, weight_variants, base_price_per_kg`,
    [name, basePricePerKg, basePricePerKg, weightVariants, stock, unit]
  );
  return rows[0];
}

async function seedPieceProduct({ name, price = 60, stock = 50 }) {
  const { rows } = await query(
    `INSERT INTO products (name, price, stock, unit, active)
     VALUES ($1, $2, $3, 'piece', TRUE)
     RETURNING id, name, stock`,
    [name, price, stock]
  );
  return rows[0];
}

async function seedOrderWithItems({
  customerId,
  items,
  status = 'CONFIRMED',
  paymentMode = 'COD',
  totalAmount = null,
}) {
  const address = JSON.stringify({ text: 'Test Address', lat: 12.972, lng: 77.595 });
  const computedTotal =
    totalAmount ??
    items.reduce((sum, i) => sum + Number(i.price) * Number(i.quantity), 0);

  const { rows: orderRows } = await query(
    `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode, payment_status)
     VALUES ($1, $2, $3, $4::jsonb, $5, 'PENDING')
     RETURNING id, status, total_amount`,
    [customerId, status, computedTotal, address, paymentMode]
  );
  const order = orderRows[0];

  const insertedItems = [];
  for (const item of items) {
    const { rows } = await query(
      `INSERT INTO order_items (order_id, product_id, quantity, price, ordered_weight_g)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, product_id, ordered_weight_g, price`,
      [
        order.id,
        item.productId,
        item.quantity ?? 1,
        item.price,
        item.orderedWeightG ?? null,
      ]
    );
    insertedItems.push(rows[0]);
  }

  return { order, items: insertedItems };
}

async function getOrder(orderId) {
  const { rows } = await query('SELECT * FROM orders WHERE id = $1', [orderId]);
  return rows[0];
}

async function getOrderItems(orderId) {
  const { rows } = await query(
    `SELECT * FROM order_items WHERE order_id = $1 ORDER BY id`,
    [orderId]
  );
  return rows;
}

async function getReconciliationLog(orderId) {
  const { rows } = await query(
    `SELECT * FROM order_weight_reconciliations WHERE order_id = $1 ORDER BY id`,
    [orderId]
  );
  return rows;
}

async function getPartialRefunds(orderId) {
  const { rows } = await query(
    `SELECT * FROM order_partial_refunds WHERE order_id = $1 ORDER BY id`,
    [orderId]
  );
  return rows;
}

async function getInventoryMovements(orderId) {
  const { rows } = await query(
    `SELECT * FROM inventory_movements WHERE order_id = $1 ORDER BY id`,
    [orderId]
  );
  return rows;
}

async function getProductStock(productId) {
  const { rows } = await query('SELECT stock FROM products WHERE id = $1', [productId]);
  return Number(rows[0]?.stock || 0);
}

async function cleanupTestData(ids) {
  const { orderIds = [], userIds = [], productIds = [] } = ids;
  if (orderIds.length) {
    await query('DELETE FROM operational_events WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM inventory_movements WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM order_partial_refunds WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query(
      'DELETE FROM order_weight_reconciliations WHERE order_id = ANY($1::bigint[])',
      [orderIds]
    );
    await query('DELETE FROM order_items WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM orders WHERE id = ANY($1::bigint[])', [orderIds]);
  }
  if (productIds.length) {
    await query('DELETE FROM products WHERE id = ANY($1::bigint[])', [productIds]);
  }
  if (userIds.length) {
    await query('DELETE FROM users WHERE id = ANY($1::bigint[])', [userIds]);
  }
}

module.exports = {
  ensureSchema,
  query,
  pool,
  seedUser,
  seedWeightProduct,
  seedPieceProduct,
  seedOrderWithItems,
  getOrder,
  getOrderItems,
  getReconciliationLog,
  getPartialRefunds,
  getInventoryMovements,
  getProductStock,
  cleanupTestData,
  packOrderWithWeightReconciliation,
  executePackingWeightReconciliation,
  assignOrderToPartner,
  WEIGHT_ACTION,
  TEST_PREFIX,
};
