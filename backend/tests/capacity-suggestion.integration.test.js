/**
 * Integration tests — capacity suggestion system (Phase 3).
 * @jest-environment node
 */
require('dotenv').config();

const { query, pool } = require('../src/db/postgres');
const { ensureSchema } = require('../src/db/ensureSchema');
const {
  evaluateAndPersistSuggestion,
  getActiveCapacitySuggestion,
  dismissCapacitySuggestion,
  evaluateCapacitySuggestion,
} = require('../src/services/capacitySuggestion.service');
const { CAPACITY_SUGGESTION } = require('../src/config/businessRules');
const { STORE_ACCEPTANCE_MODE } = require('../src/constants/storeAcceptanceMode.constants');
const { setStoreAcceptanceMode } = require('../src/utils/storeSettings.util');
const {
  seedUser,
  seedDeliveryPartner,
  cleanupTestData,
  TEST_PREFIX,
} = require('./helpers/riderOperationsHarness');

async function seedPackedOrder({ customerId, packedAt = new Date() }) {
  const { rows } = await query(
    `INSERT INTO orders (
       customer_id, status, total_amount, address, payment_method,
       confirmed_at, packed_at, dispatch_queued_at
     ) VALUES ($1, 'PACKED', 500, '{"lat":23.66,"lng":86.18}'::jsonb, 'COD',
               NOW(), $2, $2)
     RETURNING id`,
    [customerId, packedAt]
  );
  return Number(rows[0].id);
}

async function seedConfirmedOrder({ customerId, confirmedAt = new Date() }) {
  const { rows } = await query(
    `INSERT INTO orders (
       customer_id, status, total_amount, address, payment_method, confirmed_at
     ) VALUES ($1, 'CONFIRMED', 500, '{"lat":23.66,"lng":86.18}'::jsonb, 'COD', $2)
     RETURNING id`,
    [customerId, confirmedAt]
  );
  return Number(rows[0].id);
}

async function countSuggestions() {
  const { rows } = await query(`SELECT COUNT(*)::int AS count FROM capacity_suggestions`);
  return Number(rows[0]?.count || 0);
}

async function setPartnerOnline(partnerId, online = true) {
  await query(
    `UPDATE delivery_partners SET is_online = $1, approved = TRUE WHERE id = $2`,
    [online, partnerId]
  );
}

async function assignMaxLoadToPartner(partnerId, customerId, count) {
  const orderIds = [];
  for (let i = 0; i < count; i += 1) {
    const orderId = await seedPackedOrder({ customerId });
    orderIds.push(orderId);
    await query(
      `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
       VALUES ($1, $2, 'ACCEPTED')`,
      [orderId, partnerId]
    );
    await query(`UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = $1`, [orderId]);
  }
  return orderIds;
}

describe('capacity suggestion integration', () => {
  const orderIds = [];
  const userIds = [];
  let customer;
  let riderPartner;

  beforeAll(async () => {
    await ensureSchema();
    customer = await seedUser({ role: 'CUSTOMER', phone: `${TEST_PREFIX}cap_cust` });
    userIds.push(customer.id);

    const riderUser = await seedUser({ role: 'DELIVERY', phone: `${TEST_PREFIX}cap_rider` });
    userIds.push(riderUser.id);
    riderPartner = await seedDeliveryPartner(riderUser.id);
  });

  afterAll(async () => {
    await query('DELETE FROM capacity_suggestions');
    await cleanupTestData({ orderIds, userIds });
    await pool.end();
  });

  beforeEach(async () => {
    await query('DELETE FROM capacity_suggestions');
    await query(
      `DELETE FROM order_assignments WHERE order_id IN (
         SELECT id FROM orders WHERE customer_id = $1
       )`,
      [customer.id]
    );
    await query(`DELETE FROM orders WHERE customer_id = $1`, [customer.id]);
    orderIds.length = 0;
    await setStoreAcceptanceMode(STORE_ACCEPTANCE_MODE.ACCEPTING);
    await setPartnerOnline(riderPartner.id, false);
  });

  test('creates suggestion when dispatch queue exceeds threshold', async () => {
    const backlog = CAPACITY_SUGGESTION.peakReadyBacklog + 1;
    for (let i = 0; i < backlog; i += 1) {
      orderIds.push(await seedPackedOrder({ customerId: customer.id }));
    }

    const before = await countSuggestions();
    const result = await evaluateAndPersistSuggestion();
    const after = await countSuggestions();

    expect(result.suggestion).not.toBeNull();
    expect(result.suggestion.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);
    expect(after).toBeGreaterThan(before);

    const active = await getActiveCapacitySuggestion();
    expect(active.active).toBe(true);
    expect(active.suggestion.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);
  });

  test('clears suggestion when pressure drops and store is in limited capacity', async () => {
    await setStoreAcceptanceMode(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);

    const evaluation = evaluateCapacitySuggestion({
      signals: {
        queueCount: CAPACITY_SUGGESTION.clearQueueThreshold,
        confirmedRecent: CAPACITY_SUGGESTION.clearConfirmedThreshold,
        activeRiders: 1,
        availableRiders: 1,
        riderCapacityUsed: 0.5,
        allRidersAtCapacity: false,
        noAvailableRiders: false,
        queueGrowing: false,
      },
      currentMode: STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY,
    });

    expect(evaluation?.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.ACCEPTING);

    await query(
      `INSERT INTO capacity_suggestions
         (suggested_mode, current_mode, reason, severity, signals)
       VALUES ($1, $2, 'pressure_cleared', 'INFO', '{}'::jsonb)`,
      [STORE_ACCEPTANCE_MODE.ACCEPTING, STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY]
    );

    const active = await getActiveCapacitySuggestion();
    expect(active.suggestion?.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.ACCEPTING);
  });

  test('apply mode uses existing acceptance-mode path without auto-switching', async () => {
    await setStoreAcceptanceMode(STORE_ACCEPTANCE_MODE.ACCEPTING);
    const settings = await setStoreAcceptanceMode(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);
    expect(settings.acceptance_mode).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);

    const { readOperationalSettings, resolveAcceptanceMode } = require('../src/utils/storeSettings.util');
    const operational = await readOperationalSettings();
    expect(resolveAcceptanceMode(operational)).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);

    await setStoreAcceptanceMode(STORE_ACCEPTANCE_MODE.ACCEPTING);
  });

  test('dismiss suppresses repeat active suggestion until TTL expires', async () => {
    for (let i = 0; i < CAPACITY_SUGGESTION.peakReadyBacklog + 1; i += 1) {
      orderIds.push(await seedPackedOrder({ customerId: customer.id }));
    }

    await evaluateAndPersistSuggestion();
    const dismissResult = await dismissCapacitySuggestion(30);
    expect(dismissResult.dismissed).toBe(true);

    const suppressed = await evaluateAndPersistSuggestion();
    expect(suppressed.suppressed).toBe(true);

    const active = await getActiveCapacitySuggestion();
    expect(active.suggestion).toBeNull();
    expect(active.active).toBe(false);
  });

  test('rider capacity pressure creates limited capacity suggestion', async () => {
    await setPartnerOnline(riderPartner.id, true);
    const loadOrders = await assignMaxLoadToPartner(
      riderPartner.id,
      customer.id,
      CAPACITY_SUGGESTION.peakReadyBacklog > 0 ? 2 : 2
    );
    orderIds.push(...loadOrders);

    orderIds.push(await seedPackedOrder({ customerId: customer.id }));

    const result = await evaluateAndPersistSuggestion();
    expect(result.suggestion).not.toBeNull();
    expect(result.suggestion.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);
    expect(result.suggestion.reason).toMatch(/all_riders_at_capacity|no_rider_queue_growing|dispatch_queue_high/);
  });
});
