/**
 * Integration tests — business metrics aggregation (Phase 5).
 * @jest-environment node
 */
require('dotenv').config();

const { query, pool } = require('../src/db/postgres');
const { ensureSchema } = require('../src/db/ensureSchema');
const {
  getOpsMetrics,
  computeOpsMetricsForRange,
  upsertDailyRollup,
  fetchDailyRollups,
} = require('../src/services/businessMetrics.service');
const { OPERATIONAL_EVENT_TYPES } = require('../src/constants/operationalEvent.constants');
const {
  seedUser,
  cleanupTestData,
  TEST_PREFIX,
} = require('./helpers/riderOperationsHarness');

describe('business metrics integration', () => {
  const orderIds = [];
  const userIds = [];
  let customer;

  beforeAll(async () => {
    await ensureSchema();
    customer = await seedUser({
      phone: `${TEST_PREFIX}_bm_cust`,
      role: 'customer',
      name: 'BM Customer',
    });
    userIds.push(customer.id);
  });

  afterAll(async () => {
    await query('DELETE FROM business_metrics_daily_rollup WHERE metric_date >= CURRENT_DATE - 2');
    await cleanupTestData({ orderIds, userIds });
    await pool.end();
  });

  async function seedDeliveredOrder({
    dispatchDelayMin = 10,
    packedTimeMin = 20,
    tripTimeMin = 15,
  } = {}) {
    const now = Date.now();
    const confirmedAt = new Date(now - 120 * 60_000).toISOString();
    const packingStartedAt = new Date(now - 100 * 60_000).toISOString();
    const packedAt = new Date(now - (100 - packedTimeMin) * 60_000).toISOString();
    const dispatchQueuedAt = packedAt;
    const assignedAt = new Date(
      new Date(dispatchQueuedAt).getTime() + dispatchDelayMin * 60_000
    ).toISOString();
    const outForDeliveryAt = new Date(
      new Date(assignedAt).getTime() + 5 * 60_000
    ).toISOString();
    const deliveredAt = new Date(
      new Date(outForDeliveryAt).getTime() + tripTimeMin * 60_000
    ).toISOString();

    const { rows } = await query(
      `INSERT INTO orders (
         customer_id, status, total_amount, address, payment_mode, payment_status,
         confirmed_at, packing_started_at, packed_at, dispatch_queued_at,
         assigned_at, out_for_delivery_at, delivered_at, created_at
       )
       VALUES (
         $1, 'DELIVERED', 450, '{"text":"Metrics Test"}'::jsonb, 'COD', 'PAID',
         $2, $3, $4, $5, $6, $7, $8, NOW()
       )
       RETURNING id`,
      [
        customer.id,
        confirmedAt,
        packingStartedAt,
        packedAt,
        dispatchQueuedAt,
        assignedAt,
        outForDeliveryAt,
        deliveredAt,
      ]
    );
    const orderId = rows[0].id;
    orderIds.push(orderId);
    return orderId;
  }

  test('computes timing metrics from lifecycle timestamps', async () => {
    await seedDeliveredOrder({
      dispatchDelayMin: 12,
      packedTimeMin: 25,
      tripTimeMin: 18,
    });

    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - 1);

    const { metrics, dataCompleteness } = await computeOpsMetricsForRange(start, end);

    expect(metrics.averageDispatchDelay.dataAvailable).toBe(true);
    expect(metrics.averageDispatchDelay.value).toBeGreaterThan(10);
    expect(metrics.averagePackedTime.dataAvailable).toBe(true);
    expect(metrics.averageRiderTripTime.dataAvailable).toBe(true);
    expect(dataCompleteness.metricsAvailable).toBeGreaterThan(0);
  });

  test('computes batch percentage from delivery_batches', async () => {
    const soloOrder = await seedDeliveredOrder();
    const batchOrderA = await seedDeliveredOrder();
    const batchOrderB = await seedDeliveredOrder();

    await query(
      `INSERT INTO delivery_batches (anchor_order_id, batch_size, order_ids)
       VALUES ($1, 1, $2::jsonb)`,
      [soloOrder, JSON.stringify([soloOrder])]
    );
    await query(
      `INSERT INTO delivery_batches (anchor_order_id, batch_size, order_ids)
       VALUES ($1, 2, $2::jsonb)`,
      [batchOrderA, JSON.stringify([batchOrderA, batchOrderB])]
    );

    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - 1);

    const { metrics } = await computeOpsMetricsForRange(start, end);

    expect(metrics.batchPercentage.dataAvailable).toBe(true);
    expect(metrics.soloVsBatchRatio.batch).toBeGreaterThanOrEqual(2);
    expect(metrics.soloVsBatchRatio.solo).toBeGreaterThanOrEqual(1);
  });

  test('tracks cancellations by reason from operational_events', async () => {
    const { rows } = await query(
      `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode, payment_status)
       VALUES ($1, 'CANCELLED', 200, '{"text":"Cancel"}'::jsonb, 'COD', 'PENDING')
       RETURNING id`,
      [customer.id]
    );
    const orderId = rows[0].id;
    orderIds.push(orderId);

    await query(
      `INSERT INTO operational_events (event_type, order_id, payload)
       VALUES ($1, $2, $3::jsonb)`,
      [
        OPERATIONAL_EVENT_TYPES.CANCELLED,
        orderId,
        JSON.stringify({ metadata: { reason: 'Customer requested cancellation' } }),
      ]
    );

    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - 1);

    const { metrics } = await computeOpsMetricsForRange(start, end);
    const reasons = metrics.ordersCancelledByReason;

    expect(Array.isArray(reasons)).toBe(true);
    expect(
      reasons.some((r) => r.reason.includes('Customer requested') && r.count >= 1)
    ).toBe(true);
  });

  test('getOpsMetrics returns period, trends, and dataCompleteness', async () => {
    const result = await getOpsMetrics({ period: '7d', granularity: 'day' });

    expect(result.period).toBe('7d');
    expect(result.granularity).toBe('day');
    expect(result.metrics).toBeDefined();
    expect(Array.isArray(result.trends)).toBe(true);
    expect(result.dataCompleteness).toBeDefined();
    expect(result.dataCompleteness).toHaveProperty('overallScore');
  });

  test('daily rollup can be stored and fetched without changing API shape', async () => {
    const metricDate = new Date();
    metricDate.setDate(metricDate.getDate() - 1);

    await upsertDailyRollup(
      metricDate,
      {
        batchPercentage: { value: 33.3, dataAvailable: true, sampleSize: 3 },
        dailySnapshot: { orders: 5, revenue: 1200 },
      },
      { overallScore: 80, metricsAvailable: 4, metricsTotal: 5 }
    );

    const start = new Date(metricDate);
    start.setHours(0, 0, 0, 0);
    const end = new Date(metricDate);
    end.setDate(end.getDate() + 1);

    const rollups = await fetchDailyRollups(start, end);
    expect(rollups.length).toBeGreaterThanOrEqual(1);
    expect(rollups[0].metrics.batchPercentage.value).toBe(33.3);
  });

  test('returns honest nulls when no historical data in isolated window', async () => {
    const end = new Date('2020-01-02T00:00:00.000Z');
    const start = new Date('2020-01-01T00:00:00.000Z');

    const { metrics, dataCompleteness } = await computeOpsMetricsForRange(start, end);

    expect(metrics.batchPercentage.value).toBeNull();
    expect(metrics.batchPercentage.dataAvailable).toBe(false);
    expect(dataCompleteness.overallScore).toBeLessThan(100);
  });
});
