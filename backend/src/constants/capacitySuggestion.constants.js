const { STORE_ACCEPTANCE_MODE } = require('./storeAcceptanceMode.constants');

const CAPACITY_SUGGESTION_SEVERITY = Object.freeze({
  INFO: 'INFO',
  WARNING: 'WARNING',
  CRITICAL: 'CRITICAL',
});

const CAPACITY_SUGGESTION_REASON = Object.freeze({
  DISPATCH_QUEUE: 'dispatch_queue_high',
  CONFIRMED_ORDERS: 'confirmed_orders_high',
  RIDERS_AT_CAPACITY: 'all_riders_at_capacity',
  NO_RIDER_QUEUE_GROWING: 'no_rider_queue_growing',
  PRESSURE_CLEARED: 'pressure_cleared',
});

module.exports = {
  CAPACITY_SUGGESTION_SEVERITY,
  CAPACITY_SUGGESTION_REASON,
  SUGGESTABLE_MODES: Object.freeze([
    STORE_ACCEPTANCE_MODE.ACCEPTING,
    STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY,
  ]),
};
