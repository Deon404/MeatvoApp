jest.mock('../src/db/postgres', () => ({
  query: jest.fn(),
}));

jest.mock('../src/modules/payments/cashfree.service', () => ({
  createRefund: jest.fn(),
}));

const cashfreeService = require('../src/modules/payments/cashfree.service');
const {
  isOnlinePayment,
  buildIdempotencyKey,
  submitPartialRefundToGateway,
} = require('../src/services/cashfreeRefund.service');
const { FAILED_DELIVERY_REFUND_REASON } = require('../src/constants/weightReconciliation.constants');

describe('cashfree refund service — unit', () => {
  describe('isOnlinePayment', () => {
    test('recognizes ONLINE only', () => {
      expect(isOnlinePayment('ONLINE')).toBe(true);
      expect(isOnlinePayment('online')).toBe(true);
      expect(isOnlinePayment('COD')).toBe(false);
      expect(isOnlinePayment('')).toBe(false);
    });
  });

  describe('buildIdempotencyKey', () => {
    test('builds stable alphanumeric keys within 40 chars', () => {
      const key = buildIdempotencyKey({
        orderId: 12345,
        partialRefundId: 99,
        reason: 'weight_reconciliation',
      });
      expect(key).toMatch(/^wr12345r99$/);
      expect(key.length).toBeLessThanOrEqual(40);

      const fdKey = buildIdempotencyKey({
        orderId: 12345,
        partialRefundId: 'fd12345',
        reason: FAILED_DELIVERY_REFUND_REASON,
      });
      expect(fdKey.startsWith('fd')).toBe(true);
    });
  });

  describe('submitPartialRefundToGateway idempotency', () => {
    test('skips when gateway_refund_id already set', async () => {
      const mockClient = {
        query: jest.fn().mockResolvedValue({
          rows: [
            {
              id: 1,
              order_id: 10,
              amount: 50,
              reason: 'weight_reconciliation',
              status: 'SUBMITTED',
              payment_mode: 'ONLINE',
              gateway_refund_id: 'cf_ref_123',
              idempotency_key: 'wr10r1',
            },
          ],
        }),
      };

      const result = await submitPartialRefundToGateway({
        partialRefundId: 1,
        client: mockClient,
      });

      expect(result).toEqual({
        submitted: true,
        skipped: true,
        reason: 'already_submitted',
      });
      expect(cashfreeService.createRefund).not.toHaveBeenCalled();
    });
  });
});
