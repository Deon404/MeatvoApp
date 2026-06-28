/**
 * Authoritative business-rules configuration for Meatvo single-store operations.
 *
 * All dispatch, batching, assignment, ETA, store, pricing, and weight-policy
 * thresholds should be read from this module — not hardcoded in services.
 *
 * Environment overrides (existing only):
 *   STORE_SETTINGS_CACHE_TTL_MS, BATCH_WAIT_MS, ASSIGNMENT_TIMEOUT_MS, SMALL_FLEET_THRESHOLD
 *
 * @see backend/docs/BUSINESS_RULES.md
 */

const { STORE_ACCEPTANCE_MODE } = require('../constants/storeAcceptanceMode.constants');

/** @param {string} envName @param {number} fallback */
const envNumber = (envName, fallback) => {
  const parsed = Number(process.env[envName]);
  return Number.isFinite(parsed) ? parsed : fallback;
};

// ─── Store & serviceability (authority: was storeSettings.util.js) ───────────

const STORE = Object.freeze({
  deliveryRadiusKm: 8.0,
  centerLat: 23.6583,
  centerLng: 86.1764,
  minOrderAmount: 150.0,
  deliveryFee: 30.0,
  freeDeliveryAbove: 500.0,
  isOpen: true,
  manualOpen: true,
  withinHours: true,
  storeOpenTime: '09:00',
  storeCloseTime: '22:00',
  closedReason: null,
  closedMessage: null,
  nextOpenDisplay: null,
  acceptanceMode: STORE_ACCEPTANCE_MODE.ACCEPTING,
  capacityMessage: null,
  cacheTtlMs: envNumber('STORE_SETTINGS_CACHE_TTL_MS', 60_000),
  dbReadTimeoutMs: 5_000,
  istTimezone: 'Asia/Kolkata',
  /** Admin validation bounds for zone updates */
  minDeliveryRadiusKm: 0.5,
  maxDeliveryRadiusKm: 100,
});

/** Flat object matching legacy DEFAULT_STORE_SETTINGS field names */
const DEFAULT_STORE_SETTINGS = Object.freeze({
  delivery_radius_km: STORE.deliveryRadiusKm,
  center_lat: STORE.centerLat,
  center_lng: STORE.centerLng,
  min_order_amount: STORE.minOrderAmount,
  delivery_fee: STORE.deliveryFee,
  free_delivery_above: STORE.freeDeliveryAbove,
  is_open: STORE.isOpen,
  manual_open: STORE.manualOpen,
  within_hours: STORE.withinHours,
  store_open_time: STORE.storeOpenTime,
  store_close_time: STORE.storeCloseTime,
  closed_reason: STORE.closedReason,
  closed_message: STORE.closedMessage,
  next_open_display: STORE.nextOpenDisplay,
  acceptance_mode: STORE.acceptanceMode,
  capacity_message: STORE.capacityMessage,
});

/** DDL / schema seed defaults — aligned with STORE */
const SCHEMA_DEFAULTS = Object.freeze({
  deliveryRadiusKm: STORE.deliveryRadiusKm,
  centerLat: STORE.centerLat,
  centerLng: STORE.centerLng,
  minOrderAmount: STORE.minOrderAmount,
  deliveryFee: STORE.deliveryFee,
});

// ─── Assignment & dispatch ───────────────────────────────────────────────────

const ASSIGNMENT = Object.freeze({
  maxAttempts: 3,
  attemptTtlSeconds: 24 * 60 * 60,
  timeoutMs: envNumber('ASSIGNMENT_TIMEOUT_MS', 10_000),
  smallFleetThreshold: envNumber('SMALL_FLEET_THRESHOLD', 3),
  /** Hard cap on concurrent assigned / out-for-delivery orders per rider */
  maxActiveOrders: envNumber('RIDER_MAX_ACTIVE_ORDERS', 2),
  /** Rider→customer distance tiers (km); extended tier equals service radius */
  distanceTiersKm: Object.freeze([3, 5, STORE.deliveryRadiusKm]),
  /** Default param when tier not specified — preserved legacy behavior */
  defaultPartnerSearchRadiusKm: 5,
  scoring: Object.freeze({
    distanceWeight: 0.35,
    acceptanceWeight: 0.25,
    loadWeight: 0.2,
    ratingWeight: 0.1,
    zoneWeight: 0.1,
    distancePenaltyPerKm: 15,
    loadPenaltyPerActiveOrder: 25,
    zoneFamiliarityDeliveryCap: 10,
    zoneScoreMultiplier: 10,
    defaultRatingOutOf5: 4.0,
    maxScore: 100,
  }),
  /** Fallback distance when coords missing (earnings projection) */
  fallbackDistanceKm: 2,
});

// ─── Pack age monitoring (dispatch queue SLA) ────────────────────────────────

const PACK_AGE = Object.freeze({
  dispatchPriorityMinutes: envNumber('PACK_AGE_PRIORITY_MINUTES', 12),
  warningMinutes: envNumber('PACK_AGE_WARNING_MINUTES', 15),
  criticalMinutes: envNumber('PACK_AGE_CRITICAL_MINUTES', 20),
  monitorIntervalMs: envNumber('PACK_AGE_MONITOR_MS', 60_000),
});

/** Kitchen queue depth that triggers a store-level peak alert (operational event). */
const OPERATIONS = Object.freeze({
  peakQueueThreshold: envNumber('PEAK_QUEUE_THRESHOLD', 15),
  peakAlertCooldownSeconds: envNumber('PEAK_ALERT_COOLDOWN_SECONDS', 300),
});

// ─── Capacity suggestion (Phase 3 — advisory only, never auto-switches mode) ─

const CAPACITY_SUGGESTION = Object.freeze({
  /** PACKED / dispatch-ready orders waiting for rider assignment */
  peakReadyBacklog: envNumber('CAPACITY_PEAK_READY_BACKLOG', 5),
  /** Confirmed orders within rolling window before suggesting limited capacity */
  peakConfirmedOrders: envNumber('CAPACITY_PEAK_CONFIRMED_ORDERS', 7),
  /** Hysteresis: queue must fall at or below this to suggest returning to accepting */
  clearQueueThreshold: envNumber('CAPACITY_CLEAR_QUEUE_THRESHOLD', 2),
  /** Hysteresis: confirmed window count must fall at or below this to clear */
  clearConfirmedThreshold: envNumber('CAPACITY_CLEAR_CONFIRMED_THRESHOLD', 4),
  /** Rolling window for confirmed-order pressure signal (minutes) */
  confirmedWindowMinutes: envNumber('CAPACITY_CONFIRMED_WINDOW_MINUTES', 15),
  /** Scheduler interval (ms) */
  monitorIntervalMs: envNumber('CAPACITY_SUGGESTION_MONITOR_MS', 60_000),
  /** Debounce window after operational events before re-evaluating (ms) */
  eventDebounceMs: envNumber('CAPACITY_SUGGESTION_DEBOUNCE_MS', 5_000),
  /** Default admin dismiss TTL (minutes) */
  defaultDismissMinutes: envNumber('CAPACITY_SUGGESTION_DISMISS_MINUTES', 30),
  /** Lookback for queue-growth comparison (seconds) */
  queueGrowthLookbackSeconds: envNumber('CAPACITY_QUEUE_GROWTH_LOOKBACK_SECONDS', 60),
});

// ─── Order batching ──────────────────────────────────────────────────────────

const BATCHING = Object.freeze({
  radiusKm: 2.0,
  maxBatchSize: 4,
  waitMs: envNumber('BATCH_WAIT_MS', 3 * 60 * 1000),
  /** Store→customer distance above this skips batch wait; half of service radius */
  edgeZoneSkipKm: STORE.deliveryRadiusKm / 2,
  lookbackMinutes: 10,
});

// ─── ETA (live tracking — eta.service.js) ────────────────────────────────────

const ETA = Object.freeze({
  roadDistanceFactor: 1.2,
  bufferMinutes: 2,
  nearbyThresholdKm: 0.5,
  nearbyThresholdMeters: 500,
  initialFallbackMinutes: 30,
  initialPackingMinutes: 10,
  riderHistoricalLookbackDays: 30,
  riderSpeedClampMinKmh: 10,
  riderSpeedClampMaxKmh: 50,
  fallbackAvgDistanceKm: 2,
  vehicleSpeedsKmh: Object.freeze({
    bike: 25,
    scooter: 30,
    motorcycle: 35,
    car: 40,
    bicycle: 15,
    walking: 5,
    default: 25,
  }),
  trafficFactors: Object.freeze({
    7: 1.3,
    8: 1.4,
    9: 1.3,
    12: 1.2,
    13: 1.2,
    17: 1.4,
    18: 1.5,
    19: 1.3,
    20: 1.2,
    default: 1.0,
  }),
});

// ─── Tracking (tracking.service.js — legacy parallel ETA path) ─────────────────

const TRACKING = Object.freeze({
  nearbyThresholdKm: ETA.nearbyThresholdKm,
  offlineThresholdMs: 5 * 60 * 1000,
  positionCacheFreshMs: 30 * 1000,
  nearbyNotificationEtaMinutes: 5,
  etaBufferFactor: 1.2,
  minEtaMinutes: 5,
  vehicleSpeedsKmh: Object.freeze({
    bike: 25,
    scooter: 30,
    bicycle: 15,
    car: 35,
    default: 25,
  }),
});

// ─── Route optimization (admin / rider TSP) ────────────────────────────────

const ROUTING = Object.freeze({
  avgSpeedKmh: 20,
  stopMinutes: 5,
});

// ─── Rider return ETA (Phase 4 — observe mode in assignment metadata only) ─

const RETURN_ETA = Object.freeze({
  /** When true, assignment attaches return ETA metadata without changing scoring or selection. */
  observeMode: true,
});

// ─── Weight reconciliation ───────────────────────────────────────────────────

const WEIGHT = Object.freeze({
  toleranceG: 50,
});

// ─── Pricing fallbacks (checkout) ────────────────────────────────────────────

const PRICING = Object.freeze({
  defaultDeliveryFee: STORE.deliveryFee,
  freeDeliveryThreshold: STORE.freeDeliveryAbove,
});

// ─── Resolvers (env-aware) ───────────────────────────────────────────────────

const resolveBatchWaitMs = () => {
  const env = Number(process.env.BATCH_WAIT_MS);
  return Number.isFinite(env) && env >= 0 ? env : BATCHING.waitMs;
};

const resolveAssignmentTimeoutMs = () =>
  envNumber('ASSIGNMENT_TIMEOUT_MS', ASSIGNMENT.timeoutMs);

/**
 * Assignment scoring — extracted for regression testing; algorithm unchanged.
 */
const computeAssignmentScore = ({
  distanceKm,
  acceptanceRate,
  rating,
  activeOrders = 0,
  zoneFamiliarity = 0,
}) => {
  const s = ASSIGNMENT.scoring;
  const distanceScore = Math.max(0, s.maxScore - distanceKm * s.distancePenaltyPerKm);
  const acceptanceScore = acceptanceRate * s.maxScore;
  const loadScore = Math.max(0, s.maxScore - activeOrders * s.loadPenaltyPerActiveOrder);
  const ratingScore = (rating / 5) * s.maxScore;
  const zoneScore = Math.min(
    s.maxScore,
    zoneFamiliarity * s.zoneScoreMultiplier
  );
  return (
    distanceScore * s.distanceWeight +
    acceptanceScore * s.acceptanceWeight +
    loadScore * s.loadWeight +
    ratingScore * s.ratingWeight +
    zoneScore * s.zoneWeight
  );
};

const getTrafficMultiplier = (date = new Date()) => {
  const hour = date.getHours();
  return ETA.trafficFactors[hour] ?? ETA.trafficFactors.default;
};

module.exports = {
  STORE,
  DEFAULT_STORE_SETTINGS,
  SCHEMA_DEFAULTS,
  ASSIGNMENT,
  PACK_AGE,
  OPERATIONS,
  CAPACITY_SUGGESTION,
  BATCHING,
  ETA,
  TRACKING,
  ROUTING,
  RETURN_ETA,
  WEIGHT,
  PRICING,
  resolveBatchWaitMs,
  resolveAssignmentTimeoutMs,
  computeAssignmentScore,
  getTrafficMultiplier,
  envNumber,
};
