/**
 * Integration tests: failed delivery & return-to-store workflow.
 *
 * Run: cd backend && npm run test:integration
 * Requires PostgreSQL (DATABASE_URL or .env defaults).
 */
const {
  ensureSchema,
  pool,
  seedUser,
  seedDeliveryPartner,
  seedOrder,
  seedAssignment,
  getOrder,
  getOpenTask,
  cleanupTestData,
  markFailedDelivery,
  confirmReturnToStore,
  resolveFailedDelivery,
  manualAssignOrderToPartner,
  isOrderBlockedFromAssignment,
  TEST_PREFIX,
} = require('./helpers/failedDeliveryHarness');

const hasDatabase = Boolean(process.env.DATABASE_URL || process.env.PGHOST);

describe('Failed delivery integration', () => {
  const tracker = { orderIds: [], userIds: [], productIds: [] };
  let customer;
  let riderUser;
  let riderPartner;
  let adminUser;
  let dbAvailable = false;

  const testIfDb = (name, fn) => {
    test(name, async () => {
      if (!dbAvailable) return;
      await fn();
    });
  };

  beforeAll(async () => {
    if (!hasDatabase) return;
    try {
      await pool.query('SELECT 1');
      dbAvailable = true;
      await ensureSchema();
      customer = await seedUser({
        phone: `${TEST_PREFIX}_cust`,
        role: 'customer',
        name: 'Test Customer',
      });
      riderUser = await seedUser({
        phone: `${TEST_PREFIX}_rider`,
        role: 'delivery',
        name: 'Test Rider',
      });
      adminUser = await seedUser({
        phone: `${TEST_PREFIX}_admin`,
        role: 'admin',
        name: 'Test Admin',
      });
      riderPartner = await seedDeliveryPartner(riderUser.id);
      tracker.userIds.push(customer.id, riderUser.id, adminUser.id);
    } catch (err) {
      console.warn('Skipping integration tests — database unavailable:', err.message);
      dbAvailable = false;
    }
  });

  afterAll(async () => {
    if (dbAvailable) {
      await cleanupTestData(tracker);
    }
    try {
      await pool.end();
    } catch (_) {
      /* ignore */
    }
  });

  testIfDb('unreachable customer: marks FAILED_DELIVERY, creates admin task, blocks reassignment', async () => {
    const order = await seedOrder({ customerId: customer.id });
    tracker.orderIds.push(order.id);
    await seedAssignment({ orderId: order.id, partnerId: riderPartner.id });

    const result = await markFailedDelivery({
      orderId: order.id,
      riderUserId: riderUser.id,
      reason: 'CUSTOMER_UNREACHABLE',
      io: null,
    });

    expect(result.order.status).toBe('FAILED_DELIVERY');
    expect(result.order.failed_delivery_reason).toBe('CUSTOMER_UNREACHABLE');
    expect(result.order.failed_delivery_resolution).toBe('PENDING');

    const task = await getOpenTask(order.id);
    expect(task).toBeTruthy();
    expect(task.task_type).toBe('failed_delivery');

    const updated = await getOrder(order.id);
    expect(updated.payment_status).toBe('PENDING');
    expect(isOrderBlockedFromAssignment(updated)).toBe(true);

    const assignResult = await manualAssignOrderToPartner({
      orderId: order.id,
      deliveryPartnerId: riderPartner.id,
      io: null,
    });
    expect(assignResult.assigned).toBe(false);
    expect(assignResult.reason).toBe('order_not_assignable');
  });

  testIfDb('customer refused: return-to-store records condition and timestamps', async () => {
    const order = await seedOrder({ customerId: customer.id });
    tracker.orderIds.push(order.id);
    await seedAssignment({ orderId: order.id, partnerId: riderPartner.id });

    await markFailedDelivery({
      orderId: order.id,
      riderUserId: riderUser.id,
      reason: 'CUSTOMER_REFUSED',
      io: null,
    });

    const returnResult = await confirmReturnToStore({
      orderId: order.id,
      riderUserId: riderUser.id,
      returnCondition: 'PARTIAL_SPOILAGE',
      io: null,
    });

    expect(returnResult.order.returned_at).toBeTruthy();
    expect(Number(returnResult.order.returned_by)).toBe(Number(riderUser.id));
    expect(returnResult.order.return_reason).toBe('CUSTOMER_REFUSED');
    expect(returnResult.order.return_condition).toBe('PARTIAL_SPOILAGE');
  });

  testIfDb('admin resolution REDELIVER: order returns to PACKED and allows reassignment', async () => {
    const order = await seedOrder({ customerId: customer.id });
    tracker.orderIds.push(order.id);
    await seedAssignment({ orderId: order.id, partnerId: riderPartner.id });

    await markFailedDelivery({
      orderId: order.id,
      riderUserId: riderUser.id,
      reason: 'WRONG_ADDRESS',
      io: null,
    });
    await confirmReturnToStore({
      orderId: order.id,
      riderUserId: riderUser.id,
      returnCondition: 'RESELLABLE',
      io: null,
    });

    const resolved = await resolveFailedDelivery({
      orderId: order.id,
      adminUserId: adminUser.id,
      resolution: 'REDELIVER',
      io: null,
    });

    expect(resolved.order.status).toBe('PACKED');
    expect(resolved.order.failed_delivery_resolution).toBe('REDELIVER');

    const task = await getOpenTask(order.id);
    expect(task).toBeFalsy();

    const assignResult = await manualAssignOrderToPartner({
      orderId: order.id,
      deliveryPartnerId: riderPartner.id,
      io: null,
    });
    expect(assignResult.assigned).toBe(true);
  });

  testIfDb('admin resolution REFUND: restores stock and sets payment REFUNDED', async () => {
    const order = await seedOrder({ customerId: customer.id, paymentMode: 'COD' });
    tracker.orderIds.push(order.id);
    await seedAssignment({ orderId: order.id, partnerId: riderPartner.id });

    const { rows: itemRows } = await pool.query(
      'SELECT product_id FROM order_items WHERE order_id = $1',
      [order.id]
    );
    const productId = itemRows[0].product_id;
    tracker.productIds.push(productId);

    const stockBefore = (
      await pool.query('SELECT stock FROM products WHERE id = $1', [productId])
    ).rows[0].stock;

    await markFailedDelivery({
      orderId: order.id,
      riderUserId: riderUser.id,
      reason: 'CUSTOMER_UNREACHABLE',
      io: null,
    });
    await confirmReturnToStore({
      orderId: order.id,
      riderUserId: riderUser.id,
      returnCondition: 'DISCARD',
      io: null,
    });

    const resolved = await resolveFailedDelivery({
      orderId: order.id,
      adminUserId: adminUser.id,
      resolution: 'REFUND',
      io: null,
    });

    expect(resolved.order.status).toBe('REFUNDED');
    expect(resolved.order.payment_status).toBe('REFUNDED');

    const stockAfter = (
      await pool.query('SELECT stock FROM products WHERE id = $1', [productId])
    ).rows[0].stock;
    expect(Number(stockAfter)).toBe(Number(stockBefore) + 1);
  });
});
