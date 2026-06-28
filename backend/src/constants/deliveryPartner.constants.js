/**
 * Fleet operational status for delivery partners (Phase 4 — Rider Return ETA).
 * Distinct from rider exception `operational_status` (delayed_vehicle, need_assistance, …).
 */
const FLEET_OPERATIONAL_STATUS = Object.freeze({
  AVAILABLE: 'available',
  BUSY: 'busy',
  OFFLINE: 'offline',
});

const FLEET_OPERATIONAL_STATUS_SET = new Set(Object.values(FLEET_OPERATIONAL_STATUS));

/** Socket event emitted when return ETA or fleet status changes. */
const RIDER_RETURN_ETA_SOCKET_EVENT = 'rider:return_eta_updated';

module.exports = {
  FLEET_OPERATIONAL_STATUS,
  FLEET_OPERATIONAL_STATUS_SET,
  RIDER_RETURN_ETA_SOCKET_EVENT,
};
