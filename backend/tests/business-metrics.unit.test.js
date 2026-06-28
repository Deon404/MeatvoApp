/**
 * Unit tests — business metrics helpers (Phase 5).
 */
const {
  normalizePeriod,
  normalizeGranularity,
  resolvePeriodBounds,
  metricValue,
  buildDataCompleteness,
  percentChange,
} = require('../src/services/businessMetrics.util');

describe('businessMetrics — period helpers', () => {
  test('normalizePeriod maps aliases', () => {
    expect(normalizePeriod('week')).toBe('7d');
    expect(normalizePeriod('month')).toBe('30d');
    expect(normalizePeriod('today')).toBe('today');
    expect(normalizePeriod('7d')).toBe('7d');
    expect(normalizePeriod('invalid')).toBe('7d');
  });

  test('normalizeGranularity defaults today to hour', () => {
    expect(normalizeGranularity(undefined, 'today')).toBe('hour');
    expect(normalizeGranularity('day', '7d')).toBe('day');
  });

  test('resolvePeriodBounds for today starts at midnight', () => {
    const now = new Date('2026-06-28T15:30:00.000Z');
    const bounds = resolvePeriodBounds('today', now);
    expect(bounds.period).toBe('today');
    expect(bounds.start.getHours()).toBe(0);
    expect(bounds.end.getTime()).toBe(now.getTime());
    expect(bounds.previousEnd.getTime()).toBe(bounds.start.getTime());
  });

  test('resolvePeriodBounds for 7d spans seven days', () => {
    const now = new Date('2026-06-28T12:00:00.000Z');
    const bounds = resolvePeriodBounds('7d', now);
    const days = (bounds.end - bounds.start) / (24 * 60 * 60 * 1000);
    expect(days).toBeGreaterThanOrEqual(7);
    expect(days).toBeLessThan(8);
  });
});

describe('businessMetrics — metricValue', () => {
  test('returns null when sample below minimum', () => {
    const result = metricValue(12.5, { sampleSize: 0, minSample: 1 });
    expect(result.value).toBeNull();
    expect(result.dataAvailable).toBe(false);
    expect(result.sampleSize).toBe(0);
  });

  test('returns value when sample sufficient', () => {
    const result = metricValue(42.7, { sampleSize: 10, minSample: 1, unit: 'minutes' });
    expect(result.value).toBe(42.7);
    expect(result.dataAvailable).toBe(true);
    expect(result.unit).toBe('minutes');
  });

  test('rejects NaN values', () => {
    const result = metricValue(Number.NaN, { sampleSize: 5 });
    expect(result.dataAvailable).toBe(false);
    expect(result.value).toBeNull();
  });
});

describe('businessMetrics — buildDataCompleteness', () => {
  test('computes overall score from metric entries', () => {
    const completeness = buildDataCompleteness({
      batchPercentage: { dataAvailable: true, sampleSize: 10 },
      refundPercentage: { dataAvailable: false, sampleSize: 0, reason: 'no_refunds' },
    });

    expect(completeness.metricsTotal).toBe(2);
    expect(completeness.metricsAvailable).toBe(1);
    expect(completeness.overallScore).toBe(50);
    expect(completeness.metrics).toHaveLength(2);
    expect(completeness.message).toContain('1 of 2');
  });
});

describe('businessMetrics — percentChange', () => {
  test('handles zero previous', () => {
    expect(percentChange(10, 0)).toBe(100);
    expect(percentChange(0, 0)).toBe(0);
  });

  test('computes rounded delta', () => {
    expect(percentChange(150, 100)).toBe(50);
  });
});
