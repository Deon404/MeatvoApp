/**
 * Integration tests for P0 rider operations & dispatch safeguards.
 * @jest-environment node
 */
const {
  ensureSchema,
  pool,
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
  createOpenAdminTask,
  resolveAdminTaskByOrder,
  resolveBatchQueueContext,
  query,
  MAX_ACTIVE_ORDERS,
  ASSIGNMENT,
  PACK_AGE,
  ADMIN_TASK_TYPES,
  TEST_PREFIX,
} = require('./helpers/riderOperationsHarness');

describe('P0 rider operations safeguards', () => {
  const orderIds = [];
  const userIds = [];
  let customer;
  let riderUser;
  let riderPartner;

  beforeAll(async () => {
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
    riderPartner = await seedDeliveryPartner(riderUser.id);
    userIds.push(customer.id, riderUser.id);
  });

  afterAll(async () => {
    await cleanupTestData({ orderIds, userIds });
    await pool.end();
  });

  describe('rider load cap', () => {
    test('maxActiveOrders is configurable via businessRules', () => {
      expect(ASSIGNMENT.maxActiveOrders).toBe(2);
      expect(MAX_ACTIVE_ORDERS).toBe(2);
    });

    test('blocks assignment when rider already has 2 active orders', async () => {
      const active1 = await seedActiveDeliveryOrder({
        customerId: customer.id,
        partnerId: riderPartner.id,
      });
      const active2 = await seedActiveDeliveryOrder({
        customerId: customer.id,
        partnerId: riderPartner.id,
      });
      const queued = await seedPackedOrder(customer.id);
      orderIds.push(active1.id, active2.id, queued.id);

      expect(await countRiderActiveOrders(riderPartner.id)).toBe(2);

      const result = await manualAssignOrderToPartner({
        orderId: queued.id,
        deliveryPartnerId: riderPartner.id,
        io: null,
      });

      expect(result.assigned).toBe(false);
      expect(result.reason).toBe('rider_load_cap');

      const queue = await getDispatchQueueOrders();
      expect(queue.some((row) => Number(row.id) === Number(queued.id))).toBe(true);
    });

    test('processDispatchQueue assigns after a delivery slot opens', async () => {
      const active1 = await seedActiveDeliveryOrder({
        customerId: customer.id,
        partnerId: riderPartner.id,
      });
      const queued = await seedPackedOrder(customer.id);
      orderIds.push(active1.id, queued.id);

      await query(
        `UPDATE orders SET status = 'DELIVERED' WHERE id = $1`,
        [active1.id]
      );
      await query(
        `UPDATE order_assignments SET status = 'DELIVERED' WHERE order_id = $1`,
        [active1.id]
      );

      const dispatch = await processDispatchQueue(null);
      expect(dispatch.assigned).toContain(Number(queued.id));
    });
  });

  describe('pack age monitoring', () => {
    test('computes pack age tiers at configured thresholds', () => {
      expect(getPackAgeTier(10)).toBe('normal');
      expect(getPackAgeTier(PACK_AGE.dispatchPriorityMinutes)).toBe('priority');
      expect(getPackAgeTier(PACK_AGE.warningMinutes)).toBe('warning');
      expect(getPackAgeTier(PACK_AGE.criticalMinutes)).toBe('critical');
    });

    test('dispatch queue prioritizes older packed orders', async () => {
      const older = await seedPackedOrder(customer.id, { packedMinutesAgo: 15 });
      const newer = await seedPackedOrder(customer.id, { packedMinutesAgo: 1 });
      orderIds.push(older.id, newer.id);

      const queue = await getDispatchQueueOrders({ limit: 50 });
      const olderIdx = queue.findIndex((r) => Number(r.id) === Number(older.id));
      const newerIdx = queue.findIndex((r) => Number(r.id) === Number(newer.id));
      expect(olderIdx).toBeGreaterThanOrEqual(0);
      expect(newerIdx).toBeGreaterThanOrEqual(0);
      expect(olderIdx).toBeLessThan(newerIdx);
    });

    test('monitorPackAge emits warning and critical alerts once', async () => {
      const warningOrder = await seedPackedOrder(customer.id, {
        packedMinutesAgo: PACK_AGE.warningMinutes + 1,
      });
      const criticalOrder = await seedPackedOrder(customer.id, {
        packedMinutesAgo: PACK_AGE.criticalMinutes + 1,
      });
      orderIds.push(warningOrder.id, criticalOrder.id);

      const first = await monitorPackAge(null);
      expect(first.warnings).toBeGreaterThanOrEqual(1);
      expect(first.critical).toBeGreaterThanOrEqual(1);

      const second = await monitorPackAge(null);
      expect(second.warnings).toBe(0);
      expect(second.critical).toBe(0);

      const { rows: events } = await query(
        `SELECT event_type FROM operational_events WHERE order_id = ANY($1::bigint[])`,
        [[warningOrder.id, criticalOrder.id]]
      );
      const types = events.map((e) => e.event_type);
      expect(types).toContain('pack_age_warning');
      expect(types).toContain('pack_age_critical');
    });
  });

  describe('assignment failure admin tasks', () => {
    test('creates persistent assignment_failed admin task', async () => {
      const order = await seedPackedOrder(customer.id);
      orderIds.push(order.id);

      await createOpenAdminTask(null, {
        taskType: ADMIN_TASK_TYPES.ASSIGNMENT_FAILED,
        orderId: order.id,
        payload: { attempts: 3 },
      });

      const task = await getOpenTask(order.id, ADMIN_TASK_TYPES.ASSIGNMENT_FAILED);
      expect(task).toBeTruthy();
      expect(task.status).toBe('open');

      const resolved = await resolveAdminTaskByOrder(null, {
        orderId: order.id,
        taskType: ADMIN_TASK_TYPES.ASSIGNMENT_FAILED,
        adminUserId: customer.id,
      });
      expect(resolved).toBe(true);
    });
  });

  describe('rider operational exceptions', () => {
    test('reports exception without cancelling order', async () => {
      const order = await seedActiveDeliveryOrder({
        customerId: customer.id,
        partnerId: riderPartner.id,
      });
      orderIds.push(order.id);

      const result = await reportRiderOperationalException({
        orderId: order.id,
        riderUserId: riderUser.id,
        exceptionType: 'NEED_ASSISTANCE',
        io: null,
      });

      expect(result.exceptionType).toBe('NEED_ASSISTANCE');
      expect(result.operationalStatus).toBe('need_assistance');

      const { rows: orderRows } = await query('SELECT status FROM orders WHERE id = $1', [
        order.id,
      ]);
      expect(orderRows[0].status).toBe('OUT_FOR_DELIVERY');

      const { rows: partnerRows } = await query(
        'SELECT operational_status FROM delivery_partners WHERE id = $1',
        [riderPartner.id]
      );
      expect(partnerRows[0].operational_status).toBe('need_assistance');

      const { rows: events } = await query(
        `SELECT event_type FROM operational_events WHERE order_id = $1`,
        [order.id]
      );
      expect(events.some((e) => e.event_type === 'OPERATIONAL_EXCEPTION')).toBe(true);
    });
  });

  describe('honest batch ETA', () => {
    test('non-first stop returns queue position and adjusted ETA', async () => {
      const orderA = await seedPackedOrder(customer.id);
      const orderB = await seedPackedOrder(customer.id);
      orderIds.push(orderA.id, orderB.id);

      const batchIds = JSON.stringify([orderA.id, orderB.id]);
      await query(
        `INSERT INTO order_assignments (order_id, delivery_partner_id, status, batch_ids)
         VALUES ($1, $2, 'ACCEPTED', $3::jsonb),
                ($4, $2, 'ACCEPTED', $3::jsonb)
         ON CONFLICT (order_id) DO UPDATE SET batch_ids = EXCLUDED.batch_ids`,
        [orderA.id, riderPartner.id, batchIds, orderB.id]
      );
      await query(
        `UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = ANY($1::bigint[])`,
        [[orderA.id, orderB.id]]
      );

      const riderLocation = { lat: 12.9716, lng: 77.5946 };
      const context = await resolveBatchQueueContext(orderB.id, riderLocation);

      expect(context).toBeTruthy();
      expect(context.isFirstStop).toBe(false);
      expect(context.queuePosition).toBeGreaterThan(1);
      expect(context.stopsRemaining).toBeGreaterThanOrEqual(0);
      expect(context.adjustedETA).toBeGreaterThan(0);
      expect(context.message).toBe('Rider is completing earlier deliveries.');
    });
  });
});
