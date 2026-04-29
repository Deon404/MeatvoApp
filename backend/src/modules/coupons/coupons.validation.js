const { z } = require('zod');

const listCouponsSchema = z.object({
  query: z
    .object({
      includeInactive: z
        .enum(['true', 'false'])
        .optional()
        .transform((v) => v === 'true'),
    })
    .partial()
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const createCouponSchema = z.object({
  body: z.object({
    code: z.string().trim().min(3).max(32),
    discount_type: z.enum(['PERCENT', 'FLAT']),
    discount_value: z.coerce.number().nonnegative(),
    min_order_value: z.coerce.number().nonnegative().optional(),
    max_uses: z.coerce.number().int().nonnegative().optional().nullable(),
    active: z.boolean().optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const validateCouponSchema = z.object({
  body: z.object({
    code: z.string().trim().min(1),
    amount: z.coerce.number().nonnegative(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  listCouponsSchema,
  createCouponSchema,
  validateCouponSchema,
};

