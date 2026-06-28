/**
 * Unit tests — capacity suggestion evaluation (Phase 3).
 */
const {
  evaluateCapacitySuggestion,
  resolveLimitedCapacitySeverity,
  isDismissed,
} = require('../src/services/capacitySuggestion.service');
const { CAPACITY_SUGGESTION } = require('../src/config/businessRules');
const { STORE_ACCEPTANCE_MODE } = require('../src/constants/storeAcceptanceMode.constants');
const {
  CAPACITY_SUGGESTION_REASON,
  CAPACITY_SUGGESTION_SEVERITY,
} = require('../src/constants/capacitySuggestion.constants');

const baseSignals = {
  queueCount: 0,
  confirmedRecent: 0,
  activeRiders: 2,
  availableRiders: 2,
  riderCapacityUsed: 0,
  allRidersAtCapacity: false,
  noAvailableRiders: false,
  queueGrowing: false,
};

const testRules = {
  peakReadyBacklog: 5,
  peakConfirmedOrders: 7,
  clearQueueThreshold: 2,
  clearConfirmedThreshold: 4,
  confirmedWindowMinutes: 15,
};

describe('capacitySuggestion — limited capacity triggers', () => {
  test('queue trigger suggests limited capacity', () => {
    const result = evaluateCapacitySuggestion({
      signals: { ...baseSignals, queueCount: 6 },
      currentMode: STORE_ACCEPTANCE_MODE.ACCEPTING,
      rules: testRules,
    });

    expect(result).not.toBeNull();
    expect(result.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);
    expect(result.reason).toContain(CAPACITY_SUGGESTION_REASON.DISPATCH_QUEUE);
  });

  test('confirmed orders trigger suggests limited capacity', () => {
    const result = evaluateCapacitySuggestion({
      signals: { ...baseSignals, confirmedRecent: 8 },
      currentMode: STORE_ACCEPTANCE_MODE.ACCEPTING,
      rules: testRules,
    });

    expect(result).not.toBeNull();
    expect(result.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY);
    expect(result.reason).toContain(CAPACITY_SUGGESTION_REASON.CONFIRMED_ORDERS);
    expect(result.signals.confirmedRecent).toBe(8);
  });

  test('all riders at capacity trigger suggests limited capacity', () => {
    const result = evaluateCapacitySuggestion({
      signals: {
        ...baseSignals,
        activeRiders: 2,
        availableRiders: 0,
        allRidersAtCapacity: true,
        noAvailableRiders: true,
        riderCapacityUsed: 1,
      },
      currentMode: STORE_ACCEPTANCE_MODE.ACCEPTING,
      rules: testRules,
    });

    expect(result).not.toBeNull();
    expect(result.reason).toContain(CAPACITY_SUGGESTION_REASON.RIDERS_AT_CAPACITY);
  });

  test('no available rider with growing queue trigger', () => {
    const result = evaluateCapacitySuggestion({
      signals: {
        ...baseSignals,
        queueCount: 3,
        availableRiders: 0,
        noAvailableRiders: true,
        queueGrowing: true,
      },
      currentMode: STORE_ACCEPTANCE_MODE.ACCEPTING,
      rules: testRules,
    });

    expect(result).not.toBeNull();
    expect(result.reason).toContain(CAPACITY_SUGGESTION_REASON.NO_RIDER_QUEUE_GROWING);
  });
});

describe('capacitySuggestion — hysteresis', () => {
  test('does not suggest accepting until all clear thresholds met', () => {
    const almostClear = evaluateCapacitySuggestion({
      signals: {
        ...baseSignals,
        queueCount: 2,
        confirmedRecent: 5,
        availableRiders: 1,
      },
      currentMode: STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY,
      rules: testRules,
    });
    expect(almostClear).toBeNull();

    const stillHighConfirmed = evaluateCapacitySuggestion({
      signals: {
        ...baseSignals,
        queueCount: 1,
        confirmedRecent: 5,
        availableRiders: 2,
      },
      currentMode: STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY,
      rules: testRules,
    });
    expect(stillHighConfirmed).toBeNull();
  });

  test('suggests accepting only when queue, confirmed, and rider availability clear', () => {
    const result = evaluateCapacitySuggestion({
      signals: {
        ...baseSignals,
        queueCount: 2,
        confirmedRecent: 4,
        availableRiders: 1,
      },
      currentMode: STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY,
      rules: testRules,
    });

    expect(result).not.toBeNull();
    expect(result.suggestedMode).toBe(STORE_ACCEPTANCE_MODE.ACCEPTING);
    expect(result.reason).toBe(CAPACITY_SUGGESTION_REASON.PRESSURE_CLEARED);
    expect(result.severity).toBe(CAPACITY_SUGGESTION_SEVERITY.INFO);
  });

  test('peak trigger uses higher threshold than clear trigger', () => {
    const inHysteresisBand = evaluateCapacitySuggestion({
      signals: { ...baseSignals, queueCount: 4, confirmedRecent: 6 },
      currentMode: STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY,
      rules: testRules,
    });
    expect(inHysteresisBand).toBeNull();

    const wouldTriggerLimited = evaluateCapacitySuggestion({
      signals: { ...baseSignals, queueCount: 4, confirmedRecent: 6 },
      currentMode: STORE_ACCEPTANCE_MODE.ACCEPTING,
      rules: testRules,
    });
    expect(wouldTriggerLimited).toBeNull();
  });
});

describe('capacitySuggestion — severity', () => {
  test('multiple triggers elevate severity', () => {
    const severity = resolveLimitedCapacitySeverity(
      [
        CAPACITY_SUGGESTION_REASON.DISPATCH_QUEUE,
        CAPACITY_SUGGESTION_REASON.CONFIRMED_ORDERS,
      ],
      { queueCount: 6, confirmedRecent: 8 },
      testRules
    );
    expect(severity).toBe(CAPACITY_SUGGESTION_SEVERITY.WARNING);
  });

  test('critical when many triggers or extreme backlog', () => {
    const severity = resolveLimitedCapacitySeverity(
      [
        CAPACITY_SUGGESTION_REASON.DISPATCH_QUEUE,
        CAPACITY_SUGGESTION_REASON.CONFIRMED_ORDERS,
        CAPACITY_SUGGESTION_REASON.RIDERS_AT_CAPACITY,
      ],
      { queueCount: 12, confirmedRecent: 8 },
      testRules
    );
    expect(severity).toBe(CAPACITY_SUGGESTION_SEVERITY.CRITICAL);
  });
});

describe('capacitySuggestion — dismissal TTL', () => {
  test('isDismissed respects future dismissed_until', () => {
    const future = new Date(Date.now() + 30 * 60 * 1000).toISOString();
    expect(isDismissed({ dismissed_until: future })).toBe(true);
  });

  test('isDismissed false when TTL expired or absent', () => {
    const past = new Date(Date.now() - 60 * 1000).toISOString();
    expect(isDismissed({ dismissed_until: past })).toBe(false);
    expect(isDismissed({ dismissed_until: null })).toBe(false);
    expect(isDismissed(null)).toBe(false);
  });
});

describe('capacitySuggestion — businessRules wiring', () => {
  test('thresholds exported from businessRules', () => {
    expect(CAPACITY_SUGGESTION.peakReadyBacklog).toBeGreaterThan(
      CAPACITY_SUGGESTION.clearQueueThreshold
    );
    expect(CAPACITY_SUGGESTION.peakConfirmedOrders).toBeGreaterThan(
      CAPACITY_SUGGESTION.clearConfirmedThreshold
    );
    expect(CAPACITY_SUGGESTION.monitorIntervalMs).toBe(60_000);
  });
});
