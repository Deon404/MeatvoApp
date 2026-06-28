/**
 * Regression: batch assignment must reuse cancelled assignment rows (same as manual assign).
 * @jest-environment node
 */
require('dotenv').config();

const { query, pool } = require('../src/db/postgres');
const { ensureSchema } = require('../src/db/ensureSchema');
const { assignBatchToRider } = require('../src/services/order-batcher');

const TEST_PREFIX = `br_${Date.now()}`;
const hasDatabase = Boolean(process.env.DATABASE_URL || process.env.PGHOST);

describe('batch reassignment after cancelled assignment', () => {
  let dbAvailable = false;
  const cleanup = { orderIds: [], userIds: [], partnerIds: [] };

  beforeAll(async () => {
    if (!hasDatabase) return;
    try {
      await pool.query('SELECT 1');
      dbAvailable = true;
      await ensureSchema();
    } catch (err) {
      console.warn('Skipping batch reassignment tests — database unavailable:', err.message);
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

  test('reassigns order when prior assignment was CANCELLED', async () => {
    if (!dbAvailable) return;

    const { rows: customerRows } = await query(
      `INSERT INTO users (phone, name, role)
       VALUES ($1, 'Batch Customer', 'customer')
       RETURNING id`,
      [`${TEST_PREFIX}_cust`]
    );
    cleanup.userIds.push(customerRows[0].id);

    const { rows: rider1Rows } = await query(
      `INSERT INTO users (phone, name, role)
       VALUES ($1, 'Rider One', 'delivery')
       RETURNING id`,
      [`${TEST_PREFIX}_r1`]
    );
    const { rows: rider2Rows } = await query(
      `INSERT INTO users (phone, name, role)
       VALUES ($1, 'Rider Two', 'delivery')
       RETURNING id`,
      [`${TEST_PREFIX}_r2`]
    );
    cleanup.userIds.push(rider1Rows[0].id, rider2Rows[0].id);

    const { rows: partner1Rows } = await query(
      `INSERT INTO delivery_partners (user_id, is_online, approved)
       VALUES ($1, TRUE, TRUE)
       RETURNING id, user_id`,
      [rider1Rows[0].id]
    );
    const { rows: partner2Rows } = await query(
      `INSERT INTO delivery_partners (user_id, is_online, approved)
       VALUES ($1, TRUE, TRUE)
       RETURNING id, user_id`,
      [rider2Rows[0].id]
    );
    cleanup.partnerIds.push(partner1Rows[0].id, partner2Rows[0].id);

    const address = JSON.stringify({ text: 'Test', lat: 12.972, lng: 77.595 });
    const { rows: orderRows } = await query(
      `INSERT INTO orders (
         customer_id, status, total_amount, address, payment_mode, payment_status,
         weight_reconciliation_status
       )
       VALUES ($1, 'PACKED', 500, $2::jsonb, 'COD', 'PENDING', 'COMPLETED')
       RETURNING id`,
      [customerRows[0].id, address]
    );
    const orderId = Number(orderRows[0].id);
    cleanup.orderIds.push(orderId);

    await query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status, assigned_at)
       VALUES ($1, $2, 'CANCELLED', NOW())`,
      [orderId, partner1Rows[0].id]
    );

    const assigned = await assignBatchToRider(
      partner2Rows[0].id,
      partner2Rows[0].user_id,
      [orderId],
      null
    );

    expect(assigned).toEqual([orderId]);

    const { rows: assignmentRows } = await query(
      `SELECT delivery_partner_id, status FROM order_assignments WHERE order_id = $1`,
      [orderId]
    );
    expect(assignmentRows[0].status).toBe('ASSIGNED');
    expect(Number(assignmentRows[0].delivery_partner_id)).toBe(Number(partner2Rows[0].id));
  });
});
