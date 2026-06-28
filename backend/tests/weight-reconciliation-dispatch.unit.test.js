const {
  isWeightReconciliationCompleteForDispatch,
  assertWeightReconciliationForDispatch,
  DISPATCH_RECON_ERROR,
} = require('../src/utils/weightReconciliationDispatch.util');

describe('weightReconciliationDispatch.util', () => {
  test('allows COMPLETED and NOT_REQUIRED', () => {
    expect(isWeightReconciliationCompleteForDispatch('COMPLETED')).toBe(true);
    expect(isWeightReconciliationCompleteForDispatch('not_required')).toBe(true);
  });

  test('blocks PENDING and empty status', () => {
    expect(isWeightReconciliationCompleteForDispatch('PENDING')).toBe(false);
    expect(isWeightReconciliationCompleteForDispatch('')).toBe(false);
    expect(isWeightReconciliationCompleteForDispatch(null)).toBe(false);
  });

  test('assert throws with dispatch message', () => {
    expect(() => assertWeightReconciliationForDispatch('PENDING')).toThrow(
      DISPATCH_RECON_ERROR
    );
  });
});
