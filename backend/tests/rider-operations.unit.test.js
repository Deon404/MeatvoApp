const {
  computePackAgeMinutes,
  getPackAgeTier,
} = require('../src/services/packAge.service');
const {
  isRiderAtLoadCap,
  getRiderRemainingCapacity,
  MAX_ACTIVE_ORDERS,
} = require('../src/utils/deliveryPartner.util');
const { PACK_AGE, ASSIGNMENT } = require('../src/config/businessRules');
const { RIDER_EXCEPTION_TYPE_SET } = require('../src/constants/riderException.constants');
const { ADMIN_TASK_TYPES } = require('../src/constants/failedDelivery.constants');
const { BATCH_ETA_MESSAGE } = require('../src/services/eta.service');

describe('rider operations — unit (no DB)', () => {
  describe('load cap helpers', () => {
    test('isRiderAtLoadCap at configured maximum', () => {
      expect(MAX_ACTIVE_ORDERS).toBe(ASSIGNMENT.maxActiveOrders);
      expect(isRiderAtLoadCap(1)).toBe(false);
      expect(isRiderAtLoadCap(2)).toBe(true);
      expect(isRiderAtLoadCap(3)).toBe(true);
    });

    test('getRiderRemainingCapacity', () => {
      expect(getRiderRemainingCapacity(0)).toBe(2);
      expect(getRiderRemainingCapacity(1)).toBe(1);
      expect(getRiderRemainingCapacity(2)).toBe(0);
    });
  });

  describe('pack age tiers', () => {
    test('threshold boundaries', () => {
      expect(getPackAgeTier(11)).toBe('normal');
      expect(getPackAgeTier(12)).toBe('priority');
      expect(getPackAgeTier(14)).toBe('priority');
      expect(getPackAgeTier(15)).toBe('warning');
      expect(getPackAgeTier(19)).toBe('warning');
      expect(getPackAgeTier(20)).toBe('critical');
    });

    test('computePackAgeMinutes from packed_at', () => {
      const fifteenMinAgo = new Date(Date.now() - 15 * 60_000).toISOString();
      const minutes = computePackAgeMinutes(fifteenMinAgo);
      expect(minutes).toBeGreaterThanOrEqual(14);
      expect(minutes).toBeLessThanOrEqual(16);
    });

    test('PACK_AGE config matches requirements', () => {
      expect(PACK_AGE.dispatchPriorityMinutes).toBe(12);
      expect(PACK_AGE.warningMinutes).toBe(15);
      expect(PACK_AGE.criticalMinutes).toBe(20);
    });
  });

  describe('constants', () => {
    test('rider exception types', () => {
      expect(RIDER_EXCEPTION_TYPE_SET.has('DELAYED_VEHICLE')).toBe(true);
      expect(RIDER_EXCEPTION_TYPE_SET.has('COLD_CHAIN_ISSUE')).toBe(true);
      expect(RIDER_EXCEPTION_TYPE_SET.has('NEED_ASSISTANCE')).toBe(true);
    });

    test('assignment_failed admin task type', () => {
      expect(ADMIN_TASK_TYPES.ASSIGNMENT_FAILED).toBe('assignment_failed');
    });

    test('batch ETA customer message', () => {
      expect(BATCH_ETA_MESSAGE).toBe('Rider is completing earlier deliveries.');
    });
  });
});
