/**
 * Regression: riders may only accept PACKED orders with completed weight reconciliation.
 * @jest-environment node
 */
require('dotenv').config();

const { query, pool, withTransaction } = require('../src/db/postgres');
const { ensureSchema } = require('../src/db/ensureSchema');

const TEST_PREFIX = `rag_${Date.now()}`;
const hasDatabase = Boolean(process.env.DATABASE_URL || process.env.PGHOST);

async function tryAcceptOrder({ orderId, partnerId }) {
  return withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      'SELECT id, status, weight_reconciliation_status FROM orders WHERE id = $1 FOR UPDATE',
      [orderId]
    );
    const order = orderRows[0];
    if (!order) {
      const err = new Error('Order not found');
      err.statusCode = 404;
      throw err;
    }
    if (order.status !== 'PACKED') {
      const err = new Error('Only packed orders can be accepted by a rider');
      err.statusCode = 400;
      throw err;
    }
    const reconStatus = String(order.weight_reconciliation_status || '').toUpperCase();
    if (reconStatus !== 'COMPLETED' && reconStatus !== 'NOT_REQUIRED') {
      const err = new Error('Weight reconciliation must complete before rider can accept');
      err.statusCode = 400;
      throw err;
    }

    await client.query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
       VALUES ($1, $2, 'ACCEPTED')
       ON CONFLICT (order_id)
       DO UPDATE SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = 'ACCEPTED'`,
      [orderId, partnerId]
    );
    await client.query(
      `UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = $1`,
      [orderId]
    );
    return { accepted: true };
  });
}

describe('rider accept guard', () => {
  let dbAvailable = false;
  const cleanup = { orderIds: [], userIds: [], partnerIds: [] };

  beforeAll(async () => {
    if (!hasDatabase) return;
    try {
      await pool.query('SELECT 1');
      dbAvailable = true;
      await ensureSchema();
    } catch (err) {
      console.warn('Skipping rider accept guard tests — database unavailable:', err.message);
      dbAvailable = false;
    }
  });

  afterAll(async () => {
    if (dbAvailable) {
      if (cleanup.orderIds.length) {
        await query('DELETE FROM order_assignments WHERE order_id = ANY($1::bigint[])', [
          cleanup.orderIds,
        ]);
        await query('DELETE FROM orders WHERE id = ANY($1::bigint[])', [cleanup.orderIds]);
      }
      if (cleanup.partnerIds.length) {
        await query('DELETE FROM delivery_partners WHERE id = ANY($1::int[])', [
          cleanup.partnerIds,
        ]);
      }
      if (cleanup.userIds.length) {
        await query('DELETE FROM users WHERE id = ANY($1::int[])', [cleanup.userIds]);
      }
    }
    try {
      await pool.end();
    } catch (_) {
      /* ignore */
    }
  });

  async function seedRider() {
    const { rows: userRows } = await query(
      `INSERT INTO users (phone, name, role)
       VALUES ($1, 'Guard Rider', 'delivery')
       RETURNING id`,
      [`${TEST_PREFIX}_${Date.now()}`]
    );
    cleanup.userIds.push(userRows[0].id);
    const { rows: partnerRows } = await query(
      `INSERT INTO delivery_partners (user_id, is_online, approved)
       VALUES ($1, TRUE, TRUE)
       RETURNING id`,
      [userRows[0].id]
    );
    cleanup.partnerIds.push(partnerRows[0].id);
    return partnerRows[0].id;
  }

  async function seedCustomer() {
    const { rows } = await query(
      `INSERT INTO users (phone, name, role)
       VALUES ($1, 'Guard Customer', 'customer')
       RETURNING id`,
      [`${TEST_PREFIX}_cust_${Date.now()}`]
    );
    cleanup.userIds.push(rows[0].id);
    return rows[0].id;
  }

  async function seedOrder({ status, reconStatus }) {
    const customerId = await seedCustomer();
    const address = JSON.stringify({ text: 'Test', lat: 12.972, lng: 77.595 });
    const { rows } = await query(
      `INSERT INTO orders (
         customer_id, status, total_amount, address, payment_mode, payment_status,
         weight_reconciliation_status
       )
       VALUES ($1, $2, 500, $3::jsonb, 'COD', 'PENDING', $4)
       RETURNING id, status`,
      [customerId, status, address, reconStatus]
    );
    cleanup.orderIds.push(rows[0].id);
    return rows[0].id;
  }

  test('rejects CONFIRMED orders', async () => {
    if (!dbAvailable) return;
    const partnerId = await seedRider();
    const orderId = await seedOrder({ status: 'CONFIRMED', reconStatus: 'COMPLETED' });

    await expect(tryAcceptOrder({ orderId, partnerId })).rejects.toMatchObject({
      message: 'Only packed orders can be accepted by a rider',
      statusCode: 400,
    });
  });

  test('rejects PACKED orders with pending weight reconciliation', async () => {
    if (!dbAvailable) return;
    const partnerId = await seedRider();
    const orderId = await seedOrder({ status: 'PACKED', reconStatus: 'PENDING' });

    await expect(tryAcceptOrder({ orderId, partnerId })).rejects.toMatchObject({
      message: 'Weight reconciliation must complete before rider can accept',
      statusCode: 400,
    });
  });

  test('accepts PACKED orders with completed reconciliation', async () => {
    if (!dbAvailable) return;
    const partnerId = await seedRider();
    const orderId = await seedOrder({ status: 'PACKED', reconStatus: 'COMPLETED' });

    const result = await tryAcceptOrder({ orderId, partnerId });
    expect(result.accepted).toBe(true);

    const { rows } = await query('SELECT status FROM orders WHERE id = $1', [orderId]);
    expect(rows[0].status).toBe('OUT_FOR_DELIVERY');
  });
});
