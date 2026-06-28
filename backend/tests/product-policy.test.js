const {
  reconcileLineItemWeight,
} = require('../src/services/weightReconciliation.service');
const {
  toCustomerOrderStatus,
  CUSTOMER_ORDER_STATUS,
  CUSTOMER_STATUS_LABELS,
} = require('../src/utils/customerOrderStatus.util');

describe('weightReconciliation.service', () => {
  test('accepts weight within ±50g without refund', () => {
    const result = reconcileLineItemWeight({
      orderedWeightG: 1000,
      actualWeightG: 980,
      unitPricePerKg: 500,
    });
    expect(result.action).toBe('ACCEPT');
    expect(result.refundAmount).toBe(0);
    expect(result.requiresCustomerApproval).toBe(false);
  });

  test('supplements from next cut when short by more than 50g', () => {
    const result = reconcileLineItemWeight({
      orderedWeightG: 1000,
      actualWeightG: 900,
      unitPricePerKg: 500,
      nextCutAvailableG: 200,
    });
    expect(result.action).toBe('SUPPLEMENT_FROM_NEXT_CUT');
    expect(result.supplementG).toBe(100);
    expect(result.requiresCustomerApproval).toBe(false);
  });

  test('auto-refunds when still short after next cut', () => {
    const result = reconcileLineItemWeight({
      orderedWeightG: 1000,
      actualWeightG: 900,
      unitPricePerKg: 500,
      nextCutAvailableG: 20,
    });
    expect(result.action).toBe('AUTO_REFUND');
    expect(result.refundAmount).toBe(40);
    expect(result.requiresCustomerApproval).toBe(false);
  });
});

describe('customerOrderStatus.util', () => {
  test('maps internal statuses to four customer steps', () => {
    expect(toCustomerOrderStatus('CONFIRMED')).toBe(CUSTOMER_ORDER_STATUS.CONFIRMED);
    expect(toCustomerOrderStatus('PACKED')).toBe(CUSTOMER_ORDER_STATUS.PREPARING);
    expect(toCustomerOrderStatus('QC')).toBe(CUSTOMER_ORDER_STATUS.PREPARING);
    expect(toCustomerOrderStatus('RIDER_ASSIGNED')).toBe(CUSTOMER_ORDER_STATUS.PREPARING);
    expect(toCustomerOrderStatus('OUT_FOR_DELIVERY')).toBe(
      CUSTOMER_ORDER_STATUS.OUT_FOR_DELIVERY
    );
    expect(toCustomerOrderStatus('DELIVERED')).toBe(CUSTOMER_ORDER_STATUS.DELIVERED);
  });

  test('maps FAILED_DELIVERY to delivery attempted for customers', () => {
    expect(toCustomerOrderStatus('FAILED_DELIVERY')).toBe(
      CUSTOMER_ORDER_STATUS.DELIVERY_ATTEMPTED
    );
    expect(CUSTOMER_STATUS_LABELS[CUSTOMER_ORDER_STATUS.DELIVERY_ATTEMPTED]).toBe(
      'Delivery Attempted'
    );
  });
});
