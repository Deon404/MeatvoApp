/**
 * Integration test harness for P0 rider operations safeguards.
 */
require('dotenv').config();

const { query, pool } = require('../../src/db/postgres');
const { ensureSchema } = require('../../src/db/ensureSchema');
const redis = require('../../src/db/redis');
const {
  assignOrderToPartner,
  manualAssignOrderToPartner,
} = require('../../src/services/assignment.service');
const { processDispatchQueue, getDispatchQueueOrders } = require('../../src/services/dispatch.service');
const {
  computePackAgeMinutes,
  getPackAgeTier,
  monitorPackAge,
} = require('../../src/services/packAge.service');
const { reportRiderOperationalException } = require('../../src/services/riderException.service');
const {
  countRiderActiveOrders,
  MAX_ACTIVE_ORDERS,
  refreshPartnerOperationalState,
  deriveFleetOperationalStatus,
  FLEET_OPERATIONAL_STATUS,
} = require('../../src/utils/deliveryPartner.util');
const { createOpenAdminTask, resolveAdminTaskByOrder } = require('../../src/services/adminTask.service');
const { ADMIN_TASK_TYPES } = require('../../src/constants/failedDelivery.constants');
const { resolveBatchQueueContext } = require('../../src/services/eta.service');
const { ASSIGNMENT, PACK_AGE } = require('../../src/config/businessRules');

const TEST_PREFIX = `ro_${Date.now()}`;

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

async function seedDeliveryPartner(userId, { online = true } = {}) {
  const { rows } = await query(
    `INSERT INTO delivery_partners (user_id, is_online, approved, current_lat, current_lng)
     VALUES ($1, $2, TRUE, 12.9716, 77.5946)
     ON CONFLICT (user_id) DO UPDATE
       SET is_online = EXCLUDED.is_online, approved = TRUE, current_lat = 12.9716, current_lng = 77.5946
     RETURNING id, user_id`,
    [userId, online]
  );
  return rows[0];
}

async function seedPackedOrder(customerId, { packedMinutesAgo = 0 } = {}) {
  const address = JSON.stringify({
    text: 'Test Address',
    lat: 12.972,
    lng: 77.595,
  });
  const packedAt =
    packedMinutesAgo > 0
      ? new Date(Date.now() - packedMinutesAgo * 60_000).toISOString()
      : new Date().toISOString();

  const { rows } = await query(
    `INSERT INTO orders (
       customer_id, status, total_amount, address, payment_mode, payment_status,
       weight_reconciliation_status, packed_at
     )
     VALUES ($1, 'PACKED', 500, $2::jsonb, 'COD', 'PENDING', 'COMPLETED', $3)
     RETURNING id, status, packed_at`,
    [customerId, address, packedAt]
  );
  return rows[0];
}

async function seedActiveDeliveryOrder({ customerId, partnerId, status = 'OUT_FOR_DELIVERY' }) {
  const order = await seedPackedOrder(customerId);
  await query(
    `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
     VALUES ($1, $2, 'ACCEPTED')
     ON CONFLICT (order_id) DO UPDATE
       SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = EXCLUDED.status`,
    [order.id, partnerId]
  );
  await query(`UPDATE orders SET status = $1 WHERE id = $2`, [status, order.id]);
  return order;
}

async function getOpenTask(orderId, taskType) {
  const { rows } = await query(
    `SELECT * FROM admin_tasks WHERE order_id = $1 AND task_type = $2 AND status = 'open'`,
    [orderId, taskType]
  );
  return rows[0];
}

async function cleanupTestData(ids) {
  const { orderIds = [], userIds = [] } = ids;
  if (orderIds.length) {
    await query('DELETE FROM operational_events WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM admin_tasks WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM order_assignments WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM order_items WHERE order_id = ANY($1::bigint[])', [orderIds]);
    await query('DELETE FROM orders WHERE id = ANY($1::bigint[])', [orderIds]);
    for (const orderId of orderIds) {
      await redis.del(`assign:attempts:${orderId}`);
      await redis.del(`pack_age:alert:${orderId}:warning`);
      await redis.del(`pack_age:alert:${orderId}:critical`);
    }
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
  redis,
  seedUser,
  seedDeliveryPartner,
  seedPackedOrder,
  seedActiveDeliveryOrder,
  getOpenTask,
  cleanupTestData,
  assignOrderToPartner,
  manualAssignOrderToPartner,
  processDispatchQueue,
  getDispatchQueueOrders,
  computePackAgeMinutes,
  getPackAgeTier,
  monitorPackAge,
  reportRiderOperationalException,
  countRiderActiveOrders,
  refreshPartnerOperationalState,
  deriveFleetOperationalStatus,
  FLEET_OPERATIONAL_STATUS,
  createOpenAdminTask,
  resolveAdminTaskByOrder,
  resolveBatchQueueContext,
  MAX_ACTIVE_ORDERS,
  ASSIGNMENT,
  PACK_AGE,
  ADMIN_TASK_TYPES,
  TEST_PREFIX,
};
