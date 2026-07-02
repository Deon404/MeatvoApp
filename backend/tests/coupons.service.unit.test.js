jest.mock('../src/db/postgres', () => ({
  query: jest.fn(),
}));

const { query } = require('../src/db/postgres');
const {
  validateCouponForOrder,
} = require('../src/modules/coupons/coupons.service');

describe('coupons.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('blocks reuse when the same user already has an active order with the coupon', async () => {
    query
      .mockResolvedValueOnce({
        rows: [
          {
            id: 7,
            code: 'SAVE10',
            discount_type: 'FLAT',
            discount_value: '50',
            min_order_value: '0',
            max_uses: null,
            used_count: '0',
            active: true,
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 101 }],
      });

    const result = await validateCouponForOrder({
      code: 'save10',
      orderAmount: 500,
      userId: '42',
    });

    expect(result).toEqual({
      valid: false,
      reason: 'You have already used this coupon',
    });
    expect(query).toHaveBeenCalledTimes(2);
  });

  test('returns a valid discount when the user has not used the coupon yet', async () => {
    query
      .mockResolvedValueOnce({
        rows: [
          {
            id: 7,
            code: 'SAVE10',
            discount_type: 'PERCENT',
            discount_value: '10',
            min_order_value: '100',
            max_uses: 10,
            used_count: '1',
            active: true,
          },
        ],
      })
      .mockResolvedValueOnce({
        rows: [],
      });

    const result = await validateCouponForOrder({
      code: 'SAVE10',
      orderAmount: 500,
      userId: '42',
    });

    expect(result).toMatchObject({
      valid: true,
      discountType: 'PERCENT',
      discountValue: 10,
      discountAmount: 50,
    });
  });

  test('locks the coupon row when validation runs inside a checkout transaction', async () => {
    const db = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [
            {
              id: 9,
              code: 'FIRST50',
              discount_type: 'FLAT',
              discount_value: '50',
              min_order_value: '0',
              max_uses: 1,
              used_count: '0',
              active: true,
            },
          ],
        })
        .mockResolvedValueOnce({
          rows: [],
        }),
    };

    const result = await validateCouponForOrder({
      code: 'FIRST50',
      orderAmount: 500,
      userId: '99',
      db,
      lockCoupon: true,
    });

    expect(result.valid).toBe(true);
    expect(db.query.mock.calls[0][0]).toContain('FOR UPDATE');
  });
});
