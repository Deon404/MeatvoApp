const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const createOrderSchema = z.object({
  body: z.object({
    deliveryAddress: z.string().trim().min(10).max(500),
    paymentMethod: z.enum(['COD', 'ONLINE']),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const getOrdersSchema = z.object({
  body: z.object({}).optional(),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const cancelOrderSchema = z.object({
  params: z.object({ id: idParam }),
});

const applyCouponSchema = z.object({
  body: z.object({
    code: z.string().trim().min(2).max(40),
    orderTotal: z.coerce.number().nonnegative(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const listOrdersSchema = z.object({
  query: z
    .object({
      limit: z.coerce.number().int().positive().max(200).optional(),
      offset: z.coerce.number().int().nonnegative().optional(),
    })
    .partial()
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const getOrderSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateOrderStatusSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({
    status: z.enum(['PLACED', 'CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']),
  }),
  query: z.object({}).optional(),
});

module.exports = {
  createOrderSchema,
  getOrdersSchema,
  cancelOrderSchema,
  getAllOrdersSchema: z.object({
    query: z.object({
      page: z.coerce.number().int().positive().optional(),
      limit: z.coerce.number().int().positive().max(100).optional(),
      status: z.string().optional(),
      user: z.string().optional()
    }).optional()
  }),
  getOrderSchema,
  updateOrderStatusSchema,
  listOrdersSchema,
  applyCouponSchema,
};

