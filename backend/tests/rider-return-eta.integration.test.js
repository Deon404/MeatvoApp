/**
 * Integration tests for Phase 4 — Rider Return ETA.
 * @jest-environment node
 */
const {
  ensureSchema,
  pool,
  seedUser,
  seedDeliveryPartner,
  seedPackedOrder,
  seedActiveDeliveryOrder,
  cleanupTestData,
  manualAssignOrderToPartner,
  query,
  TEST_PREFIX,
} = require('./helpers/riderOperationsHarness');
const {
  refreshPartnerOperationalState,
  deriveFleetOperationalStatus,
  FLEET_OPERATIONAL_STATUS,
} = require('../src/utils/deliveryPartner.util');
const { calculateReturnToStoreETA } = require('../src/services/eta.service');
const { RIDER_RETURN_ETA_SOCKET_EVENT } = require('../src/constants/deliveryPartner.constants');

describe('Phase 4 — Rider Return ETA', () => {
  const orderIds = [];
  const userIds = [];
  let customer;
  let riderUser;
  let riderPartner;

  beforeAll(async () => {
    await ensureSchema();
    customer = await seedUser({
      phone: `${TEST_PREFIX}_ret_cust`,
      role: 'customer',
      name: 'Return ETA Customer',
    });
    riderUser = await seedUser({
      phone: `${TEST_PREFIX}_ret_rider`,
      role: 'delivery',
      name: 'Return ETA Rider',
    });
    riderPartner = await seedDeliveryPartner(riderUser.id, { online: true });
    userIds.push(customer.id, riderUser.id);
  });

  afterAll(async () => {
    await cleanupTestData({ orderIds, userIds });
    await pool.end();
  });

  test('refreshPartnerOperationalState persists available when online with no orders', async () => {
    const snapshot = await refreshPartnerOperationalState({
      deliveryPartnerId: riderPartner.id,
      io: null,
      reason: 'test_available',
      recordEvent: false,
    });

    expect(snapshot.operationalStatus).toBe(FLEET_OPERATIONAL_STATUS.AVAILABLE);
    expect(snapshot.activeOrderCount).toBe(0);
    expect(snapshot.estimatedReturnMinutes).toBe(0);

    const { rows } = await query(
      `SELECT availability_status, active_order_count, estimated_return_minutes
       FROM delivery_partners WHERE id = $1`,
      [riderPartner.id]
    );
    expect(rows[0].availability_status).toBe('available');
    expect(Number(rows[0].active_order_count)).toBe(0);
    expect(Number(rows[0].estimated_return_minutes)).toBe(0);
  });

  test('busy rider gets positive return ETA after accepting delivery', async () => {
    const active = await seedActiveDeliveryOrder({
      customerId: customer.id,
      partnerId: riderPartner.id,
    });
    orderIds.push(active.id);

    const snapshot = await refreshPartnerOperationalState({
      deliveryPartnerId: riderPartner.id,
      io: null,
      reason: 'test_busy',
      recordEvent: false,
    });

    expect(snapshot.operationalStatus).toBe(FLEET_OPERATIONAL_STATUS.BUSY);
    expect(snapshot.activeOrderCount).toBe(1);
    expect(snapshot.estimatedReturnMinutes).toBeGreaterThan(0);
    expect(snapshot.estimatedReturnAt).toBeTruthy();

    const returnEta = await calculateReturnToStoreETA({
      riderUserId: riderUser.id,
      riderLat: 12.9716,
      riderLng: 77.5946,
      deliveryPartnerId: riderPartner.id,
    });
    expect(returnEta.estimatedReturnMinutes).toBeGreaterThan(0);
  });

  test('delivery clears busy state back to available', async () => {
    const active = await seedActiveDeliveryOrder({
      customerId: customer.id,
      partnerId: riderPartner.id,
    });
    orderIds.push(active.id);

    await refreshPartnerOperationalState({
      deliveryPartnerId: riderPartner.id,
      io: null,
      recordEvent: false,
    });

    await query(
      `UPDATE orders SET status = 'DELIVERED' WHERE id = $1`,
      [active.id]
    );
    await query(
      `UPDATE order_assignments SET status = 'DELIVERED' WHERE order_id = $1`,
      [active.id]
    );

    const snapshot = await refreshPartnerOperationalState({
      deliveryPartnerId: riderPartner.id,
      io: null,
      reason: 'test_delivered',
      recordEvent: false,
    });

    expect(snapshot.operationalStatus).toBe(FLEET_OPERATIONAL_STATUS.AVAILABLE);
    expect(snapshot.activeOrderCount).toBe(0);
    expect(snapshot.estimatedReturnMinutes).toBe(0);
  });

  test('going offline sets offline status and clears return ETA', async () => {
    await query(
      `UPDATE delivery_partners SET is_online = FALSE WHERE id = $1`,
      [riderPartner.id]
    );

    const snapshot = await refreshPartnerOperationalState({
      deliveryPartnerId: riderPartner.id,
      io: null,
      reason: 'test_offline',
      recordEvent: false,
    });

    expect(snapshot.operationalStatus).toBe(FLEET_OPERATIONAL_STATUS.OFFLINE);
    expect(snapshot.estimatedReturnMinutes).toBe(0);
    expect(snapshot.estimatedReturnAt).toBeNull();

    await query(
      `UPDATE delivery_partners SET is_online = TRUE WHERE id = $1`,
      [riderPartner.id]
    );
  });

  test('emits socket update when return ETA changes', async () => {
    const active = await seedActiveDeliveryOrder({
      customerId: customer.id,
      partnerId: riderPartner.id,
    });
    orderIds.push(active.id);

    const emitted = [];
    const mockIo = {
      to: () => ({
        emit: (event, payload) => {
          emitted.push({ event, payload });
        },
      }),
    };

    await refreshPartnerOperationalState({
      deliveryPartnerId: riderPartner.id,
      io: mockIo,
      reason: 'test_socket',
      recordEvent: false,
    });

    const returnEtaEvents = emitted.filter((e) => e.event === RIDER_RETURN_ETA_SOCKET_EVENT);
    expect(returnEtaEvents.length).toBeGreaterThan(0);
    expect(returnEtaEvents[0].payload.operationalStatus).toBe('busy');
    expect(returnEtaEvents[0].payload.estimatedReturnMinutes).toBeGreaterThan(0);
  });

  test('assignment observe mode attaches return ETA metadata for load-capped rider', async () => {
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

    const result = await manualAssignOrderToPartner({
      orderId: queued.id,
      deliveryPartnerId: riderPartner.id,
      io: null,
    });

    expect(result.assigned).toBe(false);
    expect(result.reason).toBe('rider_load_cap');
    expect(result.scoringMetadata).toBeDefined();
    expect(result.scoringMetadata.observe).toHaveLength(1);
    expect(result.scoringMetadata.observe[0].operationalStatus).toBe('busy');
    expect(result.scoringMetadata.observe[0].estimatedReturnMinutes).toBeGreaterThan(0);
    expect(result.scoringMetadata.observe[0].excludedReason).toBe('rider_load_cap');
  });

  test('deriveFleetOperationalStatus covers all states', () => {
    expect(deriveFleetOperationalStatus(true, 0)).toBe('available');
    expect(deriveFleetOperationalStatus(true, 1)).toBe('busy');
    expect(deriveFleetOperationalStatus(false, 0)).toBe('offline');
  });
});
