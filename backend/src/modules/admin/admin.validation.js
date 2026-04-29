const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const dashboardSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const listCustomersSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const listDeliveryPartnersSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const toggleDeliveryPartnerSchema = z.object({
  params: z.object({ id: idParam }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
});

const listOrdersCompatSchema = z.object({
  query: z
    .object({
      limit: z.coerce.number().int().positive().max(500).optional(),
      offset: z.coerce.number().int().nonnegative().optional(),
    })
    .partial()
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const patchOrderCompatSchema = z.object({
  params: z.object({ id: idParam }),
  body: z
    .object({
      orderStatus: z
        .enum([
          'ASSIGNED',
          'CANCELLED',
          'PLACED',
          'CONFIRMED',
          'PACKED',
          'OUT_FOR_DELIVERY',
          'DELIVERED',
        ])
        .optional(),
      deliveryUserId: z.union([z.string(), z.number()]).optional(),
    })
    .partial(),
  query: z.object({}).optional(),
});

const listCompatSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const upsertCategoryCompatSchema = z.object({
  params: z.object({ id: idParam }).partial().optional(),
  body: z
    .object({
      name: z.string().trim().min(1).optional(),
      imageUrl: z.string().trim().optional().nullable(),
      isActive: z.boolean().optional(),
      sortOrder: z.coerce.number().int().optional(),
    })
    .partial(),
  query: z.object({}).optional(),
});

const upsertProductCompatSchema = z.object({
  params: z.object({ id: idParam }).partial().optional(),
  body: z
    .object({
      name: z.string().trim().min(1).optional(),
      description: z.string().trim().optional().nullable(),
      imageUrl: z.string().trim().optional().nullable(),
      price: z.coerce.number().nonnegative().optional(),
      unit: z.string().trim().optional().nullable(),
      stockQty: z.coerce.number().int().nonnegative().optional(),
      categoryId: z.union([z.string(), z.number()]).optional().nullable(),
      isActive: z.boolean().optional(),
    })
    .partial(),
  query: z.object({}).optional(),
});

const patchDeliveryPartnerCompatSchema = z.object({
  params: z.object({ id: idParam }),
  body: z
    .object({
      approved: z.boolean().optional(),
      online: z.boolean().optional(),
      earnings: z.coerce.number().nonnegative().optional(),
      vehicle: z.string().trim().optional().nullable(),
      vehicleNumber: z.string().trim().optional().nullable(),
      licenceNumber: z.string().trim().optional().nullable(),
      bankDetails: z.string().trim().optional().nullable(),
      name: z.string().trim().optional().nullable(),
    })
    .partial(),
  query: z.object({}).optional(),
});

const deleteProductCompatSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const changeUserRoleSchema = z.object({
  body: z.object({
    role: z.enum(['customer', 'delivery_partner'])
  }),
  params: z.object({
    id: z.string().transform(Number)
  })
});

module.exports = {
  dashboardSchema,
  listCustomersSchema,
  listDeliveryPartnersSchema,
  toggleDeliveryPartnerSchema,
  listOrdersCompatSchema,
  patchOrderCompatSchema,
  listCompatSchema,
  upsertCategoryCompatSchema,
  upsertProductCompatSchema,
  patchDeliveryPartnerCompatSchema,
  deleteProductCompatSchema,
  changeUserRoleSchema,
};
