/**
 * Integration tests — operational event instrumentation (Phase 2).
 * @jest-environment node
 */
require('dotenv').config();

const { query, pool } = require('../src/db/postgres');
const { ensureSchema } = require('../src/db/ensureSchema');
const {
  publishOperationalEvent,
  instrumentOrderConfirmed,
  instrumentRiderAssigned,
  instrumentRiderAcceptedAndDispatched,
  OPERATIONAL_EVENT_TYPES,
} = require('../src/utils/operationalEvents.util');
const { getOrderOperationalTimeline } = require('../src/services/operationalEvent.service');
const { transitionOrderState } = require('../src/services/orderLifecycle.service');
const { ORDER_STATES } = require('../src/utils/enhancedOrderStateMachine');
const {
  packOrderWithWeightReconciliation,
} = require('../src/services/packingWeightReconciliation.service');
const {
  markFailedDelivery,
  confirmReturnToStore,
  resolveFailedDelivery,
  FAILED_DELIVERY_REASONS,
  RETURN_CONDITIONS,
  FAILED_DELIVERY_RESOLUTIONS,
} = require('../src/services/failedDelivery.service');
const { reportRiderOperationalException } = require('../src/services/riderException.service');
const { manualAssignOrderToPartner } = require('../src/services/assignment.service');
const {
  seedUser,
  seedDeliveryPartner,
  seedPackedOrder,
  cleanupTestData,
  TEST_PREFIX,
} = require('./helpers/riderOperationsHarness');
const {
  seedWeightProduct,
  seedOrderWithItems,
} = require('./helpers/weightReconciliationHarness');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitForEvent(orderId, eventType, { timeoutMs = 5000 } = {}) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const { rows } = await query(
      `SELECT 1 FROM operational_events WHERE order_id = $1 AND event_type = $2 LIMIT 1`,
      [orderId, eventType]
    );
    if (rows[0]) return true;
    await sleep(100);
  }
  return false;
}

async function getOrderTimestamps(orderId) {
  const { rows } = await query(
    `SELECT confirmed_at, packing_started_at, packed_at, dispatch_queued_at,
            assigned_at, rider_accepted_at, out_for_delivery_at, delivered_at, refunded_at
     FROM orders WHERE id = $1`,
    [orderId]
  );
  return rows[0];
}

describe('operational events integration', () => {
  const orderIds = [];
  const userIds = [];
  const productIds = [];
  let customer;
  let admin;
  let riderUser;
  let riderPartner;

  beforeAll(async () => {
    await ensureSchema();
    customer = await seedUser({
      phone: `${TEST_PREFIX}_oe_cust`,
      role: 'customer',
      name: 'OE Customer',
    });
    admin = await seedUser({
      phone: `${TEST_PREFIX}_oe_admin`,
      role: 'admin',
      name: 'OE Admin',
    });
    riderUser = await seedUser({
      phone: `${TEST_PREFIX}_oe_rider`,
      role: 'delivery',
      name: 'OE Rider',
    });
    riderPartner = await seedDeliveryPartner(riderUser.id);
    userIds.push(customer.id, admin.id, riderUser.id);
  });

  afterAll(async () => {
    if (productIds.length) {
      await query('DELETE FROM products WHERE id = ANY($1::bigint[])', [productIds]);
    }
    await cleanupTestData({ orderIds, userIds });
    await pool.end();
  });

  test('order confirmation stamps confirmed_at', async () => {
    const { rows } = await query(
      `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode, payment_status)
       VALUES ($1, 'PLACED', 300, '{"text":"Test"}'::jsonb, 'COD', 'PENDING')
       RETURNING id`,
      [customer.id]
    );
    const orderId = rows[0].id;
    orderIds.push(orderId);

    instrumentOrderConfirmed(null, { orderId, actorRole: 'system' });
    expect(await waitForEvent(orderId, OPERATIONAL_EVENT_TYPES.ORDER_CONFIRMED)).toBe(true);

    const ts = await getOrderTimestamps(orderId);
    expect(ts.confirmed_at).not.toBeNull();
  });

  test('weight reconciliation emits started and completed events', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_oe_wr`,
      basePricePerKg: 500,
      weightVariants: [1000],
      stock: 5,
    });
    productIds.push(product.id);

    const { order, items } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 500, orderedWeightG: 1000 }],
      totalAmount: 500,
    });
    orderIds.push(order.id);

    await transitionOrderState({
      orderId: order.id,
      newState: ORDER_STATES.PACKING_STARTED,
      actor: admin.id,
      actorRole: 'admin',
    });

    await packOrderWithWeightReconciliation({
      orderId: order.id,
      lineWeights: [{ orderItemId: items[0].id, actualWeightG: 1000 }],
      actor: admin.id,
      actorRole: 'admin',
    });

    expect(
      await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.WEIGHT_RECONCILIATION_STARTED)
    ).toBe(true);
    expect(
      await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.WEIGHT_RECONCILIATION_COMPLETED)
    ).toBe(true);
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.ORDER_PACKED)).toBe(true);
    expect(
      await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.ENTERED_DISPATCH_QUEUE)
    ).toBe(true);

    const ts = await getOrderTimestamps(order.id);
    expect(ts.packing_started_at).not.toBeNull();
    expect(ts.packed_at).not.toBeNull();
    expect(ts.dispatch_queued_at).not.toBeNull();
  });

  test('assignment retry records failure then success', async () => {
    const order = await seedPackedOrder(customer.id);
    orderIds.push(order.id);

    await publishOperationalEvent(null, {
      eventType: OPERATIONAL_EVENT_TYPES.ASSIGNMENT_FAILED,
      orderId: order.id,
      metadata: {
        assignmentAttempts: 3,
        assignmentSuccess: false,
        assignmentFailureReason: 'max_attempts_exceeded',
      },
    });

    const assignResult = await manualAssignOrderToPartner({
      orderId: order.id,
      deliveryPartnerId: riderPartner.id,
      io: null,
    });
    expect(assignResult.assigned).toBe(true);

    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.ASSIGNMENT_FAILED)).toBe(true);
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.RIDER_ASSIGNED)).toBe(true);

    const ts = await getOrderTimestamps(order.id);
    expect(ts.assigned_at).not.toBeNull();
  });

  test('batch assignment records batch metadata', async () => {
    const order1 = await seedPackedOrder(customer.id);
    const order2 = await seedPackedOrder(customer.id);
    orderIds.push(order1.id, order2.id);

    instrumentRiderAssigned(null, {
      orderId: order1.id,
      riderId: riderPartner.id,
      riderUserId: riderUser.id,
      assignmentAttempt: 1,
      batchId: 99,
      batchSize: 2,
      metadata: { anchorOrderId: order1.id },
    });
    instrumentRiderAssigned(null, {
      orderId: order2.id,
      riderId: riderPartner.id,
      riderUserId: riderUser.id,
      assignmentAttempt: 1,
      batchId: 99,
      batchSize: 2,
      metadata: { anchorOrderId: order1.id },
    });

    await publishOperationalEvent(null, {
      eventType: OPERATIONAL_EVENT_TYPES.BATCH_CREATED,
      orderId: order1.id,
      riderId: riderPartner.id,
      metadata: {
        batchId: 99,
        batchSize: 2,
        anchorOrderId: order1.id,
        orderIds: [order1.id, order2.id],
      },
    });

    expect(await waitForEvent(order1.id, OPERATIONAL_EVENT_TYPES.BATCH_CREATED)).toBe(true);
  });

  test('failed delivery, return, and refund timeline', async () => {
    const order = await seedPackedOrder(customer.id);
    orderIds.push(order.id);

    await query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
       VALUES ($1, $2, 'ACCEPTED')
       ON CONFLICT (order_id) DO UPDATE SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = EXCLUDED.status`,
      [order.id, riderPartner.id]
    );
    await query(`UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = $1`, [order.id]);

    await markFailedDelivery({
      orderId: order.id,
      riderUserId: riderUser.id,
      reason: FAILED_DELIVERY_REASONS.CUSTOMER_UNAVAILABLE,
      io: null,
    });

    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.DELIVERY_ATTEMPTED)).toBe(true);
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.FAILED_DELIVERY)).toBe(true);

    await confirmReturnToStore({
      orderId: order.id,
      riderUserId: riderUser.id,
      returnCondition: RETURN_CONDITIONS.SEALED,
      io: null,
    });
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.RETURN_TO_STORE)).toBe(true);

    await resolveFailedDelivery({
      orderId: order.id,
      adminUserId: admin.id,
      resolution: FAILED_DELIVERY_RESOLUTIONS.REFUND,
      io: null,
    });
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.REFUNDED)).toBe(true);

    const timeline = await getOrderOperationalTimeline(order.id);
    const types = timeline.events.map((e) => e.eventType);
    expect(types).toEqual(
      expect.arrayContaining([
        OPERATIONAL_EVENT_TYPES.REFUNDED,
        OPERATIONAL_EVENT_TYPES.RETURN_TO_STORE,
        OPERATIONAL_EVENT_TYPES.FAILED_DELIVERY,
      ])
    );
  });

  test('operational exception from rider', async () => {
    const order = await seedPackedOrder(customer.id);
    orderIds.push(order.id);
    await query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
       VALUES ($1, $2, 'ACCEPTED')`,
      [order.id, riderPartner.id]
    );
    await query(`UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = $1`, [order.id]);

    await reportRiderOperationalException({
      orderId: order.id,
      riderUserId: riderUser.id,
      exceptionType: 'DELAYED',
      notes: 'Traffic',
      io: null,
    });

    expect(
      await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.OPERATIONAL_EXCEPTION)
    ).toBe(true);
  });

  test('successful delivery stamps delivered_at', async () => {
    const order = await seedPackedOrder(customer.id);
    orderIds.push(order.id);

    instrumentRiderAcceptedAndDispatched(null, {
      orderId: order.id,
      riderId: riderPartner.id,
      riderUserId: riderUser.id,
    });

    await publishOperationalEvent(null, {
      eventType: OPERATIONAL_EVENT_TYPES.DELIVERED,
      orderId: order.id,
      riderId: riderPartner.id,
      actorId: riderUser.id,
      actorType: 'RIDER',
      previousState: 'OUT_FOR_DELIVERY',
      newState: 'DELIVERED',
    });
    await query(`UPDATE orders SET status = 'DELIVERED' WHERE id = $1`, [order.id]);

    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.RIDER_ACCEPTED)).toBe(true);
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.OUT_FOR_DELIVERY)).toBe(true);
    expect(await waitForEvent(order.id, OPERATIONAL_EVENT_TYPES.DELIVERED)).toBe(true);

    const ts = await getOrderTimestamps(order.id);
    expect(ts.rider_accepted_at).not.toBeNull();
    expect(ts.out_for_delivery_at).not.toBeNull();
    expect(ts.delivered_at).not.toBeNull();
  });
});
