const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const listAvailableOrdersSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const getMeSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const acceptOrderSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const rejectOrderSchema = z.object({
  params: z.object({ id: idParam }),
  body: z
    .object({
      reason: z.string().trim().max(200).optional(),
    })
    .partial()
    .optional(),
  query: z.object({}).optional(),
});

const updateDeliveryOrderStatusSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({
    status: z.enum(['OUT_FOR_DELIVERY', 'DELIVERED']),
  }),
  query: z.object({}).optional(),
});

const updateLocationSchema = z.object({
  body: z.object({
    lat: z.coerce.number(),
    lng: z.coerce.number(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const getEarningsSchema = z.object({
  query: z
    .object({
      period: z.enum(['today', 'week', 'month']).optional(),
    })
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const toggleOnlineSchema = z.object({
  body: z.object({
    is_online: z.boolean().optional(),
    online: z.boolean().optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateProfileSchema = z.object({
  body: z
    .object({
      name: z.string().trim().optional().nullable(),
      vehicle: z.string().trim().optional().nullable(),
      vehicleNumber: z.string().trim().optional().nullable(),
      licenceNumber: z.string().trim().optional().nullable(),
      bankDetails: z.string().trim().optional().nullable(),
    })
    .partial(),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  listAvailableOrdersSchema,
  getMeSchema,
  acceptOrderSchema,
  rejectOrderSchema,
  updateDeliveryOrderStatusSchema,
  updateLocationSchema,
  getEarningsSchema,
  toggleOnlineSchema,
  updateProfileSchema,
};
