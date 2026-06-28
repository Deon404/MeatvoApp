const {
  deriveFleetOperationalStatus,
  formatOperationalSnapshot,
  isRiderAtLoadCap,
  getRiderRemainingCapacity,
  MAX_ACTIVE_ORDERS,
  FLEET_OPERATIONAL_STATUS,
} = require('../src/utils/deliveryPartner.util');
const { RETURN_ETA, ASSIGNMENT } = require('../src/config/businessRules');
const { FLEET_OPERATIONAL_STATUS_SET } = require('../src/constants/deliveryPartner.constants');

describe('deliveryPartner.util — fleet operational state', () => {
  describe('deriveFleetOperationalStatus', () => {
    test('offline when not online', () => {
      expect(deriveFleetOperationalStatus(false, 0)).toBe(FLEET_OPERATIONAL_STATUS.OFFLINE);
      expect(deriveFleetOperationalStatus(false, 2)).toBe(FLEET_OPERATIONAL_STATUS.OFFLINE);
    });

    test('available when online with no active orders', () => {
      expect(deriveFleetOperationalStatus(true, 0)).toBe(FLEET_OPERATIONAL_STATUS.AVAILABLE);
    });

    test('busy when online with active orders', () => {
      expect(deriveFleetOperationalStatus(true, 1)).toBe(FLEET_OPERATIONAL_STATUS.BUSY);
      expect(deriveFleetOperationalStatus(true, 2)).toBe(FLEET_OPERATIONAL_STATUS.BUSY);
    });
  });

  describe('formatOperationalSnapshot', () => {
    test('maps DB row to API snapshot', () => {
      const snapshot = formatOperationalSnapshot({
        id: 5,
        user_id: 10,
        is_online: true,
        availability_status: 'busy',
        estimated_return_minutes: 18,
        estimated_return_at: '2026-06-28T12:00:00.000Z',
        active_order_count: 1,
      });

      expect(snapshot).toEqual({
        deliveryPartnerId: 5,
        riderUserId: 10,
        operationalStatus: 'busy',
        estimatedReturnMinutes: 18,
        estimatedReturnAt: '2026-06-28T12:00:00.000Z',
        activeOrderCount: 1,
        isOnline: true,
      });
    });

    test('derives status when availability_status missing', () => {
      const snapshot = formatOperationalSnapshot({
        id: 1,
        user_id: 2,
        is_online: false,
        active_order_count: 0,
      });
      expect(snapshot.operationalStatus).toBe(FLEET_OPERATIONAL_STATUS.OFFLINE);
    });
  });

  describe('load cap helpers', () => {
    test('MAX_ACTIVE_ORDERS matches businessRules', () => {
      expect(MAX_ACTIVE_ORDERS).toBe(ASSIGNMENT.maxActiveOrders);
      expect(MAX_ACTIVE_ORDERS).toBe(2);
    });

    test('isRiderAtLoadCap boundaries', () => {
      expect(isRiderAtLoadCap(1)).toBe(false);
      expect(isRiderAtLoadCap(2)).toBe(true);
    });

    test('getRiderRemainingCapacity', () => {
      expect(getRiderRemainingCapacity(0)).toBe(2);
      expect(getRiderRemainingCapacity(2)).toBe(0);
    });
  });

  describe('constants', () => {
    test('fleet operational status values', () => {
      expect(FLEET_OPERATIONAL_STATUS_SET.has('available')).toBe(true);
      expect(FLEET_OPERATIONAL_STATUS_SET.has('busy')).toBe(true);
      expect(FLEET_OPERATIONAL_STATUS_SET.has('offline')).toBe(true);
    });

    test('RETURN_ETA observe mode enabled', () => {
      expect(RETURN_ETA.observeMode).toBe(true);
    });
  });
});
