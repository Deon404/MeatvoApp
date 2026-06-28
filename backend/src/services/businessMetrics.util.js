const PERIOD_ALIASES = Object.freeze({
  today: 'today',
  '7d': '7d',
  week: '7d',
  '30d': '30d',
  month: '30d',
});

const VALID_PERIODS = new Set(['today', '7d', '30d']);
const VALID_GRANULARITY = new Set(['hour', 'day']);

function normalizePeriod(period = '7d') {
  const key = String(period || '7d').toLowerCase();
  const normalized = PERIOD_ALIASES[key] || key;
  return VALID_PERIODS.has(normalized) ? normalized : '7d';
}

function normalizeGranularity(granularity = 'day', period = '7d') {
  const key = String(granularity || 'day').toLowerCase();
  if (!VALID_GRANULARITY.has(key)) return period === 'today' ? 'hour' : 'day';
  if (period === 'today' && key === 'day') return 'hour';
  return key;
}

function resolvePeriodBounds(period = '7d', now = new Date()) {
  const normalized = normalizePeriod(period);
  const end = new Date(now);
  const start = new Date(now);

  if (normalized === 'today') {
    start.setHours(0, 0, 0, 0);
  } else if (normalized === '7d') {
    start.setDate(start.getDate() - 7);
    start.setHours(0, 0, 0, 0);
  } else {
    start.setDate(start.getDate() - 30);
    start.setHours(0, 0, 0, 0);
  }

  const durationMs = end.getTime() - start.getTime();
  const previousEnd = new Date(start);
  const previousStart = new Date(start.getTime() - durationMs);

  return {
    period: normalized,
    start,
    end,
    previousStart,
    previousEnd,
  };
}

function metricValue(value, { sampleSize = 0, minSample = 1, unit = null } = {}) {
  const count = Number(sampleSize || 0);
  const dataAvailable = count >= minSample && value != null && !Number.isNaN(Number(value));
  return {
    value: dataAvailable ? Number(value) : null,
    dataAvailable,
    sampleSize: count,
    ...(unit ? { unit } : {}),
  };
}

function buildDataCompleteness(metricEntries) {
  const metrics = Object.entries(metricEntries).map(([key, entry]) => ({
    key,
    dataAvailable: Boolean(entry?.dataAvailable),
    sampleSize: Number(entry?.sampleSize || 0),
    reason: entry?.dataAvailable
      ? null
      : (entry?.reason || 'insufficient_historical_data'),
  }));

  const available = metrics.filter((m) => m.dataAvailable).length;
  const total = metrics.length;

  return {
    overallScore: total > 0 ? Math.round((available / total) * 100) : 0,
    metricsAvailable: available,
    metricsTotal: total,
    metrics,
    message:
      available === total
        ? 'All metrics have sufficient data for this period.'
        : `${total - available} of ${total} metrics lack sufficient historical data for this period.`,
  };
}

function percentChange(current, previous) {
  const cur = Number(current || 0);
  const prev = Number(previous || 0);
  if (prev === 0) return cur > 0 ? 100 : 0;
  return Math.round(((cur - prev) / prev) * 100);
}

module.exports = {
  PERIOD_ALIASES,
  VALID_PERIODS,
  VALID_GRANULARITY,
  normalizePeriod,
  normalizeGranularity,
  resolvePeriodBounds,
  metricValue,
  buildDataCompleteness,
  percentChange,
};
