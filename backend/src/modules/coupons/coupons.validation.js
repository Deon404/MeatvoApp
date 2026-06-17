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
  body: z
    .object({
      code: z.string().trim().min(1),
      orderAmount: z.coerce.number().nonnegative().optional(),
      amount: z.coerce.number().nonnegative().optional(),
      userId: z.string().trim().min(1).optional(),
    })
    .refine((body) => body.orderAmount !== undefined || body.amount !== undefined, {
      message: 'orderAmount or amount is required',
    })
    .transform((body) => ({
      code: body.code,
      orderAmount: body.orderAmount ?? body.amount,
      userId: body.userId,
    })),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateCouponSchema = z.object({
  params: z.object({
    id: z.coerce.number().int().positive(),
  }),
  body: z
    .object({
      discount_type: z.enum(['PERCENT', 'FLAT']).optional(),
      discount_value: z.coerce.number().nonnegative().optional(),
      min_order_value: z.coerce.number().nonnegative().optional(),
      max_uses: z.coerce.number().int().nonnegative().optional().nullable(),
      active: z.boolean().optional(),
    })
    .refine((body) => Object.keys(body).length > 0, {
      message: 'At least one field is required',
    }),
  query: z.object({}).optional(),
});

const deleteCouponSchema = z.object({
  params: z.object({
    id: z.coerce.number().int().positive(),
  }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  listCouponsSchema,
  createCouponSchema,
  validateCouponSchema,
  updateCouponSchema,
  deleteCouponSchema,
};
