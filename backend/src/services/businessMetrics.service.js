/**
 * Phase 5 — Business / operational KPI aggregation.
 * Sources: operational_events, orders lifecycle timestamps, delivery_batches,
 * payment_transactions, order_assignments, weight reconciliation.
 */
const { query } = require('../db/postgres');
const { OPERATIONAL_EVENT_TYPES } = require('../constants/operationalEvent.constants');
const {
  PERIOD_ALIASES,
  normalizePeriod,
  normalizeGranularity,
  resolvePeriodBounds,
  metricValue,
  buildDataCompleteness,
  percentChange,
} = require('./businessMetrics.util');

async function fetchDailyRollups(start, end) {
  const { rows } = await query(
    `SELECT metric_date, metrics, data_completeness
     FROM business_metrics_daily_rollup
     WHERE metric_date >= $1::date AND metric_date < $2::date
     ORDER BY metric_date ASC`,
    [start.toISOString(), end.toISOString()]
  );
  return rows;
}

/**
 * Optional daily rollup persistence for future optimization.
 * Does not change the public API — callers may invoke from a cron later.
 */
async function upsertDailyRollup(metricDate, metrics, dataCompleteness) {
  const dateStr =
    metricDate instanceof Date
      ? metricDate.toISOString().split('T')[0]
      : String(metricDate);

  await query(
    `INSERT INTO business_metrics_daily_rollup (metric_date, metrics, data_completeness, updated_at)
     VALUES ($1::date, $2::jsonb, $3::jsonb, NOW())
     ON CONFLICT (metric_date) DO UPDATE
       SET metrics = EXCLUDED.metrics,
           data_completeness = EXCLUDED.data_completeness,
           updated_at = NOW()`,
    [dateStr, JSON.stringify(metrics), JSON.stringify(dataCompleteness)]
  );
}

async function computeBatchMetrics(start, end) {
  const { rows } = await query(
    `SELECT
       COUNT(*)::int AS total_batches,
       COUNT(*) FILTER (WHERE batch_size > 1)::int AS multi_batches,
       COALESCE(SUM(batch_size) FILTER (WHERE batch_size > 1), 0)::int AS batched_orders,
       COALESCE(SUM(batch_size) FILTER (WHERE batch_size = 1), 0)::int AS solo_batch_records
     FROM delivery_batches
     WHERE created_at >= $1 AND created_at < $2`,
    [start.toISOString(), end.toISOString()]
  );

  const row = rows[0] || {};
  const batchedOrders = Number(row.batched_orders || 0);
  const soloFromBatches = Number(row.solo_batch_records || 0);
  const totalDispatched = batchedOrders + soloFromBatches;

  const batchPct =
    totalDispatched > 0 ? (batchedOrders / totalDispatched) * 100 : null;

  const soloRatio = batchedOrders > 0 ? soloFromBatches / batchedOrders : null;

  return {
    batchPercentage: metricValue(batchPct, {
      sampleSize: totalDispatched,
      minSample: 1,
      unit: 'percent',
    }),
    soloVsBatchRatio: {
      solo: soloFromBatches,
      batch: batchedOrders,
      ratio: soloRatio != null ? Number(soloRatio.toFixed(2)) : null,
      dataAvailable: totalDispatched > 0,
      sampleSize: totalDispatched,
    },
  };
}

async function computeTimingMetrics(start, end) {
  const { rows } = await query(
    `SELECT
       COUNT(*) FILTER (
         WHERE dispatch_queued_at IS NOT NULL
           AND COALESCE(rider_accepted_at, assigned_at) IS NOT NULL
       )::int AS dispatch_delay_samples,
       AVG(
         EXTRACT(EPOCH FROM (
           COALESCE(rider_accepted_at, assigned_at) - dispatch_queued_at
         )) / 60.0
       ) FILTER (
         WHERE dispatch_queued_at IS NOT NULL
           AND COALESCE(rider_accepted_at, assigned_at) IS NOT NULL
       ) AS avg_dispatch_delay_minutes,

       COUNT(*) FILTER (
         WHERE packed_at IS NOT NULL
           AND COALESCE(packing_started_at, confirmed_at) IS NOT NULL
       )::int AS packed_time_samples,
       AVG(
         EXTRACT(EPOCH FROM (
           packed_at - COALESCE(packing_started_at, confirmed_at)
         )) / 60.0
       ) FILTER (
         WHERE packed_at IS NOT NULL
           AND COALESCE(packing_started_at, confirmed_at) IS NOT NULL
       ) AS avg_packed_time_minutes,

       COUNT(*) FILTER (
         WHERE delivered_at IS NOT NULL AND out_for_delivery_at IS NOT NULL
       )::int AS trip_time_samples,
       AVG(
         EXTRACT(EPOCH FROM (delivered_at - out_for_delivery_at)) / 60.0
       ) FILTER (
         WHERE delivered_at IS NOT NULL AND out_for_delivery_at IS NOT NULL
       ) AS avg_rider_trip_time_minutes,

       COUNT(*) FILTER (
         WHERE delivered_at IS NOT NULL AND confirmed_at IS NOT NULL
       )::int AS delivery_time_samples,
       AVG(
         EXTRACT(EPOCH FROM (delivered_at - confirmed_at)) / 60.0
       ) FILTER (
         WHERE delivered_at IS NOT NULL AND confirmed_at IS NOT NULL
       ) AS avg_end_to_end_delivery_minutes
     FROM orders
     WHERE created_at >= $1 AND created_at < $2`,
    [start.toISOString(), end.toISOString()]
  );

  const row = rows[0] || {};

  return {
    averageDispatchDelay: metricValue(row.avg_dispatch_delay_minutes, {
      sampleSize: row.dispatch_delay_samples,
      minSample: 1,
      unit: 'minutes',
    }),
    averagePackedTime: metricValue(row.avg_packed_time_minutes, {
      sampleSize: row.packed_time_samples,
      minSample: 1,
      unit: 'minutes',
    }),
    averageRiderTripTime: metricValue(row.avg_rider_trip_time_minutes, {
      sampleSize: row.trip_time_samples,
      minSample: 1,
      unit: 'minutes',
    }),
    averageEndToEndDeliveryTime: metricValue(row.avg_end_to_end_delivery_minutes, {
      sampleSize: row.delivery_time_samples,
      minSample: 1,
      unit: 'minutes',
    }),
  };
}

async function computeRefundMetrics(start, end) {
  const { rows } = await query(
    `SELECT
       COUNT(*)::int AS total_orders,
       COUNT(*) FILTER (
         WHERE status = 'REFUNDED'
           OR payment_status = 'REFUNDED'
           OR refunded_at IS NOT NULL
       )::int AS refunded_orders,
       COALESCE(SUM(weight_reconciliation_total_refund), 0)::numeric(12,2) AS weight_refund_total
     FROM orders
     WHERE created_at >= $1 AND created_at < $2`,
    [start.toISOString(), end.toISOString()]
  );

  const { rows: paymentRows } = await query(
    `SELECT COUNT(*)::int AS refunded_payments
     FROM payment_transactions pt
     JOIN orders o ON o.id = pt.order_id
     WHERE pt.status = 'REFUNDED'
       AND pt.updated_at >= $1 AND pt.updated_at < $2`,
    [start.toISOString(), end.toISOString()]
  );

  const row = rows[0] || {};
  const totalOrders = Number(row.total_orders || 0);
  const refundedOrders = Math.max(
    Number(row.refunded_orders || 0),
    Number(paymentRows[0]?.refunded_payments || 0)
  );
  const refundPct = totalOrders > 0 ? (refundedOrders / totalOrders) * 100 : null;

  return {
    refundPercentage: metricValue(refundPct, {
      sampleSize: totalOrders,
      minSample: 1,
      unit: 'percent',
    }),
    weightRefundTotal: {
      value: Number(row.weight_refund_total || 0),
      dataAvailable: totalOrders > 0,
      sampleSize: totalOrders,
      unit: 'INR',
    },
  };
}

async function computeStockFailureMetrics(start, end) {
  const { rows } = await query(
    `WITH period_orders AS (
       SELECT COUNT(*)::int AS total
       FROM orders
       WHERE created_at >= $1 AND created_at < $2
     ),
     stock_failures AS (
       SELECT COUNT(DISTINCT order_id)::int AS failures
       FROM operational_events
       WHERE event_type = $3
         AND created_at >= $1 AND created_at < $2
         AND order_id IS NOT NULL
     )
     SELECT period_orders.total, stock_failures.failures
     FROM period_orders, stock_failures`,
    [
      start.toISOString(),
      end.toISOString(),
      OPERATIONAL_EVENT_TYPES.STOCK_FAILURE,
    ]
  );

  const total = Number(rows[0]?.total || 0);
  const failures = Number(rows[0]?.failures || 0);
  const pct = total > 0 ? (failures / total) * 100 : null;

  return {
    stockFailurePercentage: metricValue(pct, {
      sampleSize: total,
      minSample: 1,
      unit: 'percent',
    }),
  };
}

async function computeCancelledByReason(start, end) {
  const { rows } = await query(
    `SELECT
       COALESCE(
         NULLIF(TRIM(payload->'metadata'->>'reason'), ''),
         NULLIF(TRIM(payload->>'reason'), ''),
         'Unknown'
       ) AS reason,
       COUNT(*)::int AS count
     FROM operational_events
     WHERE event_type = $3
       AND created_at >= $1 AND created_at < $2
     GROUP BY 1
     ORDER BY count DESC`,
    [
      start.toISOString(),
      end.toISOString(),
      OPERATIONAL_EVENT_TYPES.CANCELLED,
    ]
  );

  const total = rows.reduce((sum, r) => sum + Number(r.count || 0), 0);

  return {
    ordersCancelledByReason: rows.map((r) => ({
      reason: r.reason,
      count: Number(r.count || 0),
    })),
    dataAvailable: total > 0,
    sampleSize: total,
  };
}

async function computePeakModeHours(start, end) {
  const { rows } = await query(
    `SELECT
       EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')::int AS hour,
       COUNT(*)::int AS alert_count
     FROM operational_events
     WHERE event_type = ANY($3::text[])
       AND created_at >= $1 AND created_at < $2
     GROUP BY 1
     ORDER BY hour ASC`,
    [
      start.toISOString(),
      end.toISOString(),
      [
        OPERATIONAL_EVENT_TYPES.PEAK_ALERT_TRIGGERED,
        OPERATIONAL_EVENT_TYPES.ACCEPTANCE_MODE_CHANGED,
      ],
    ]
  );

  const totalAlerts = rows.reduce((sum, r) => sum + Number(r.alert_count || 0), 0);

  return {
    peakModeHours: rows.map((r) => ({
      hour: Number(r.hour),
      alertCount: Number(r.alert_count || 0),
    })),
    dataAvailable: totalAlerts > 0,
    sampleSize: totalAlerts,
  };
}

async function computeOpsMetricsForRange(start, end) {
  const [
    batchMetrics,
    timingMetrics,
    refundMetrics,
    stockMetrics,
    cancelledByReason,
    peakModeHours,
  ] = await Promise.all([
    computeBatchMetrics(start, end),
    computeTimingMetrics(start, end),
    computeRefundMetrics(start, end),
    computeStockFailureMetrics(start, end),
    computeCancelledByReason(start, end),
    computePeakModeHours(start, end),
  ]);

  const metrics = {
    ...batchMetrics,
    ...timingMetrics,
    ...refundMetrics,
    ...stockMetrics,
    ordersCancelledByReason: cancelledByReason.ordersCancelledByReason,
    peakModeHours: peakModeHours.peakModeHours,
  };

  const completenessEntries = {
    batchPercentage: batchMetrics.batchPercentage,
    soloVsBatchRatio: batchMetrics.soloVsBatchRatio,
    averageDispatchDelay: timingMetrics.averageDispatchDelay,
    averagePackedTime: timingMetrics.averagePackedTime,
    averageRiderTripTime: timingMetrics.averageRiderTripTime,
    refundPercentage: refundMetrics.refundPercentage,
    stockFailurePercentage: stockMetrics.stockFailurePercentage,
    ordersCancelledByReason: {
      dataAvailable: cancelledByReason.dataAvailable,
      sampleSize: cancelledByReason.sampleSize,
    },
    peakModeHours: {
      dataAvailable: peakModeHours.dataAvailable,
      sampleSize: peakModeHours.sampleSize,
    },
  };

  return {
    metrics,
    dataCompleteness: buildDataCompleteness(completenessEntries),
  };
}

async function computeTrends(start, end, granularity) {
  const truncUnit = granularity === 'hour' ? 'hour' : 'day';

  const { rows: orderTrends } = await query(
    `SELECT
       date_trunc($3, created_at AT TIME ZONE 'Asia/Kolkata') AS bucket,
       COUNT(*)::int AS orders,
       COUNT(*) FILTER (WHERE status = 'DELIVERED')::int AS delivered,
       COUNT(*) FILTER (WHERE status = 'CANCELLED')::int AS cancelled,
       COALESCE(SUM(total_amount) FILTER (WHERE status = 'DELIVERED'), 0)::numeric(12,2) AS revenue,
       AVG(
         EXTRACT(EPOCH FROM (delivered_at - out_for_delivery_at)) / 60.0
       ) FILTER (
         WHERE delivered_at IS NOT NULL AND out_for_delivery_at IS NOT NULL
       ) AS avg_trip_minutes,
       AVG(
         EXTRACT(EPOCH FROM (
           COALESCE(rider_accepted_at, assigned_at) - dispatch_queued_at
         )) / 60.0
       ) FILTER (
         WHERE dispatch_queued_at IS NOT NULL
           AND COALESCE(rider_accepted_at, assigned_at) IS NOT NULL
       ) AS avg_dispatch_delay_minutes
     FROM orders
     WHERE created_at >= $1 AND created_at < $2
     GROUP BY 1
     ORDER BY 1 ASC`,
    [start.toISOString(), end.toISOString(), truncUnit]
  );

  const { rows: batchTrends } = await query(
    `SELECT
       date_trunc($3, created_at AT TIME ZONE 'Asia/Kolkata') AS bucket,
       COALESCE(SUM(batch_size) FILTER (WHERE batch_size > 1), 0)::int AS batched_orders,
       COALESCE(SUM(batch_size) FILTER (WHERE batch_size = 1), 0)::int AS solo_orders
     FROM delivery_batches
     WHERE created_at >= $1 AND created_at < $2
     GROUP BY 1
     ORDER BY 1 ASC`,
    [start.toISOString(), end.toISOString(), truncUnit]
  );

  const batchByBucket = new Map(
    batchTrends.map((r) => [new Date(r.bucket).toISOString(), r])
  );

  return orderTrends.map((row) => {
    const bucketIso = new Date(row.bucket).toISOString();
    const batchRow = batchByBucket.get(bucketIso) || {};
    const batched = Number(batchRow.batched_orders || 0);
    const solo = Number(batchRow.solo_orders || 0);
    const dispatchTotal = batched + solo;

    return {
      bucket: bucketIso,
      orders: Number(row.orders || 0),
      delivered: Number(row.delivered || 0),
      cancelled: Number(row.cancelled || 0),
      revenue: Number(row.revenue || 0),
      avgRiderTripMinutes:
        row.avg_trip_minutes != null ? Number(Number(row.avg_trip_minutes).toFixed(1)) : null,
      avgDispatchDelayMinutes:
        row.avg_dispatch_delay_minutes != null
          ? Number(Number(row.avg_dispatch_delay_minutes).toFixed(1))
          : null,
      batchPercentage:
        dispatchTotal > 0 ? Number(((batched / dispatchTotal) * 100).toFixed(1)) : null,
      dataAvailable: Number(row.orders || 0) > 0,
    };
  });
}

/**
 * Period-over-period deltas for commerce analytics (used by getAnalytics).
 */
async function computeCommerceKpiDeltas(start, end, previousStart, previousEnd) {
  const { rows } = await query(
    `SELECT
       COUNT(*) FILTER (WHERE created_at >= $1 AND created_at < $2)::int AS cur_orders,
       COUNT(*) FILTER (WHERE created_at >= $3 AND created_at < $4)::int AS prev_orders,
       COALESCE(SUM(total_amount) FILTER (
         WHERE status = 'DELIVERED' AND created_at >= $1 AND created_at < $2
       ), 0)::numeric(12,2) AS cur_revenue,
       COALESCE(SUM(total_amount) FILTER (
         WHERE status = 'DELIVERED' AND created_at >= $3 AND created_at < $4
       ), 0)::numeric(12,2) AS prev_revenue,
       COUNT(*) FILTER (
         WHERE status = 'DELIVERED' AND created_at >= $1 AND created_at < $2
       )::int AS cur_delivered,
       COUNT(*) FILTER (
         WHERE status = 'DELIVERED' AND created_at >= $3 AND created_at < $4
       )::int AS prev_delivered
     FROM orders`,
    [
      start.toISOString(),
      end.toISOString(),
      previousStart.toISOString(),
      previousEnd.toISOString(),
    ]
  );

  const row = rows[0] || {};
  const curDelivered = Number(row.cur_delivered || 0);
  const prevDelivered = Number(row.prev_delivered || 0);
  const curRevenue = Number(row.cur_revenue || 0);
  const prevRevenue = Number(row.prev_revenue || 0);
  const curAov = curDelivered > 0 ? curRevenue / curDelivered : 0;
  const prevAov = prevDelivered > 0 ? prevRevenue / prevDelivered : 0;

  return {
    ordersChange: percentChange(row.cur_orders, row.prev_orders),
    revenueChange: percentChange(curRevenue, prevRevenue),
    aovChange: percentChange(curAov, prevAov),
  };
}

async function getOpsMetrics({
  period = '7d',
  granularity,
  useRollup = false,
  now = new Date(),
} = {}) {
  const normalizedPeriod = normalizePeriod(period);
  const normalizedGranularity = normalizeGranularity(
    granularity,
    normalizedPeriod
  );
  const bounds = resolvePeriodBounds(normalizedPeriod, now);

  let rollupUsed = false;
  if (useRollup && normalizedGranularity === 'day' && normalizedPeriod !== 'today') {
    const rollups = await fetchDailyRollups(bounds.start, bounds.end);
    const expectedDays = Math.ceil(
      (bounds.end.getTime() - bounds.start.getTime()) / (24 * 60 * 60 * 1000)
    );
    if (rollups.length >= expectedDays && rollups.length > 0) {
      rollupUsed = true;
      const mergedMetrics = rollups.reduce(
        (acc, row) => ({ ...acc, ...(row.metrics || {}) }),
        {}
      );
      const mergedCompleteness = rollups[rollups.length - 1]?.data_completeness || {};
      return {
        period: normalizedPeriod,
        granularity: normalizedGranularity,
        metrics: mergedMetrics,
        trends: rollups.map((r) => ({
          bucket: new Date(r.metric_date).toISOString(),
          ...(r.metrics?.dailySnapshot || {}),
        })),
        dataCompleteness: mergedCompleteness,
        rollupUsed: true,
      };
    }
  }

  const [{ metrics, dataCompleteness }, trends] = await Promise.all([
    computeOpsMetricsForRange(bounds.start, bounds.end),
    computeTrends(bounds.start, bounds.end, normalizedGranularity),
  ]);

  return {
    period: normalizedPeriod,
    granularity: normalizedGranularity,
    metrics,
    trends,
    dataCompleteness,
    rollupUsed,
  };
}

module.exports = {
  PERIOD_ALIASES,
  normalizePeriod,
  normalizeGranularity,
  resolvePeriodBounds,
  metricValue,
  buildDataCompleteness,
  computeOpsMetricsForRange,
  computeTrends,
  computeCommerceKpiDeltas,
  getOpsMetrics,
  upsertDailyRollup,
  fetchDailyRollups,
};
