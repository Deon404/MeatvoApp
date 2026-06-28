/**
 * Regression tests: businessRules.js must preserve pre-refactor dispatch/assignment behavior.
 */
const {
  STORE,
  DEFAULT_STORE_SETTINGS,
  SCHEMA_DEFAULTS,
  ASSIGNMENT,
  PACK_AGE,
  BATCHING,
  ETA,
  TRACKING,
  ROUTING,
  WEIGHT,
  PRICING,
  computeAssignmentScore,
  getTrafficMultiplier,
  resolveBatchWaitMs,
  resolveAssignmentTimeoutMs,
} = require('../src/config/businessRules');

describe('businessRules — store authority', () => {
  test('delivery radius is standardized at 8 km', () => {
    expect(STORE.deliveryRadiusKm).toBe(8);
    expect(DEFAULT_STORE_SETTINGS.delivery_radius_km).toBe(8);
    expect(SCHEMA_DEFAULTS.deliveryRadiusKm).toBe(8);
  });

  test('store defaults match legacy storeSettings.util.js values', () => {
    expect(STORE.centerLat).toBe(23.6583);
    expect(STORE.centerLng).toBe(86.1764);
    expect(STORE.minOrderAmount).toBe(150);
    expect(STORE.deliveryFee).toBe(30);
    expect(STORE.freeDeliveryAbove).toBe(500);
    expect(STORE.storeOpenTime).toBe('09:00');
    expect(STORE.storeCloseTime).toBe('22:00');
  });

  test('pricing fallbacks align with store settings', () => {
    expect(PRICING.defaultDeliveryFee).toBe(STORE.deliveryFee);
    expect(PRICING.freeDeliveryThreshold).toBe(STORE.freeDeliveryAbove);
  });
});

describe('businessRules — assignment (unchanged algorithm)', () => {
  test('distance tiers end at service radius', () => {
    expect(ASSIGNMENT.distanceTiersKm).toEqual([3, 5, 8]);
    expect(ASSIGNMENT.distanceTiersKm[2]).toBe(STORE.deliveryRadiusKm);
  });

  test('core assignment limits preserved', () => {
    expect(ASSIGNMENT.maxAttempts).toBe(3);
    expect(ASSIGNMENT.maxActiveOrders).toBe(2);
    expect(ASSIGNMENT.smallFleetThreshold).toBe(3);
    expect(ASSIGNMENT.defaultPartnerSearchRadiusKm).toBe(5);
    expect(resolveAssignmentTimeoutMs()).toBe(10_000);
  });

  test('scoring produces legacy values for reference inputs', () => {
    const score = computeAssignmentScore({
      distanceKm: 2,
      acceptanceRate: 1,
      rating: 4,
      activeOrders: 0,
      zoneFamiliarity: 5,
    });
    // distance: 70*0.35=24.5, acceptance: 100*0.25=25, load: 100*0.2=20,
    // rating: 80*0.1=8, zone: 50*0.1=5
    expect(score).toBeCloseTo(82.5, 5);
  });

  test('scoring degrades with distance and load as before', () => {
    const near = computeAssignmentScore({
      distanceKm: 1,
      acceptanceRate: 0.8,
      rating: 5,
      activeOrders: 0,
      zoneFamiliarity: 0,
    });
    const far = computeAssignmentScore({
      distanceKm: 6,
      acceptanceRate: 0.8,
      rating: 5,
      activeOrders: 2,
      zoneFamiliarity: 0,
    });
    expect(near).toBeGreaterThan(far);
  });
});

describe('businessRules — batching (unchanged behavior)', () => {
  test('batch constants preserved', () => {
    expect(BATCHING.radiusKm).toBe(2);
    expect(BATCHING.maxBatchSize).toBe(4);
    expect(BATCHING.waitMs).toBe(180_000);
    expect(BATCHING.lookbackMinutes).toBe(10);
  });

  test('edge zone skip is half of delivery radius', () => {
    expect(BATCHING.edgeZoneSkipKm).toBe(4);
    expect(BATCHING.edgeZoneSkipKm).toBe(STORE.deliveryRadiusKm / 2);
  });

  test('pack age thresholds configured for dispatch SLA', () => {
    expect(PACK_AGE.dispatchPriorityMinutes).toBe(12);
    expect(PACK_AGE.warningMinutes).toBe(15);
    expect(PACK_AGE.criticalMinutes).toBe(20);
  });

  test('resolveBatchWaitMs returns default without env', () => {
    const prev = process.env.BATCH_WAIT_MS;
    delete process.env.BATCH_WAIT_MS;
    expect(resolveBatchWaitMs()).toBe(180_000);
    if (prev !== undefined) process.env.BATCH_WAIT_MS = prev;
  });
});

describe('businessRules — ETA & tracking', () => {
  test('ETA nearby threshold preserved', () => {
    expect(ETA.nearbyThresholdKm).toBe(0.5);
    expect(ETA.nearbyThresholdMeters).toBe(500);
    expect(TRACKING.nearbyThresholdKm).toBe(ETA.nearbyThresholdKm);
  });

  test('traffic multiplier at hour 8 unchanged', () => {
    const date = new Date('2026-06-28T08:30:00');
    expect(getTrafficMultiplier(date)).toBe(1.4);
  });

  test('tracking vehicle speeds preserved (car 35 not 40)', () => {
    expect(TRACKING.vehicleSpeedsKmh.car).toBe(35);
    expect(ETA.vehicleSpeedsKmh.car).toBe(40);
  });

  test('routing optimizer speeds preserved', () => {
    expect(ROUTING.avgSpeedKmh).toBe(20);
    expect(ROUTING.stopMinutes).toBe(5);
  });
});

describe('businessRules — weight policy', () => {
  test('weight tolerance preserved at 50g', () => {
    expect(WEIGHT.toleranceG).toBe(50);
  });
});

describe('businessRules — conflict resolution', () => {
  test('admin/schema fallbacks use 8 km not 5 km', () => {
    expect(DEFAULT_STORE_SETTINGS.delivery_radius_km).toBe(8);
    expect(SCHEMA_DEFAULTS.deliveryRadiusKm).toBe(8);
  });
});
