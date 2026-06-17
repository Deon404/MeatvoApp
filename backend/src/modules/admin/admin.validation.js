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
      from: z.string().trim().optional(),
      to: z.string().trim().optional(),
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
    .optional(),
  query: z.object({}).optional(),
});

const assignRiderToOrderSchema = z.object({
  params: z.object({ id: idParam }),
  body: z
    .object({
      deliveryPartnerId: z.union([z.string(), z.number()]).optional(),
      resetAttempts: z.boolean().optional(),
    })
    .optional(),
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
      salePrice: z.coerce.number().nonnegative().optional(),
      mrp: z.coerce.number().nonnegative().optional().nullable(),
      basePricePerKg: z.coerce.number().nonnegative().optional(),
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

const updateStockSchema = z.object({
  params: z.object({ id: idParam }),
  body: z
    .object({
      stock: z.coerce.number().int().nonnegative().optional(),
      stockQty: z.coerce.number().int().nonnegative().optional(),
    })
    .refine((b) => b.stock !== undefined || b.stockQty !== undefined, {
      message: 'stock or stockQty is required',
    }),
  query: z.object({}).optional(),
});

const deleteCategorySchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const upsertBannerSchema = z.object({
  params: z.object({ id: idParam }).partial().optional(),
  body: z
    .object({
      imageUrl: z.string().trim().min(1).optional(),
      image_url: z.string().trim().min(1).optional(),
      isActive: z.boolean().optional(),
      active: z.boolean().optional(),
      sortOrder: z.coerce.number().int().optional(),
      sort_order: z.coerce.number().int().optional(),
    })
    .partial(),
  query: z.object({}).optional(),
});

const deleteBannerSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateSettingsSchema = z.object({
  body: z
    .object({
      theme: z.record(z.any()).optional(),
      banner: z.record(z.any()).optional(),
      delivery_charge: z.coerce.number().nonnegative().optional(),
      min_order_amount: z.coerce.number().nonnegative().optional(),
      store_open: z.boolean().optional(),
      store_open_time: z.string().trim().optional().nullable(),
      store_close_time: z.string().trim().optional().nullable(),
      delivery_radius_km: z.coerce.number().nonnegative().optional(),
      store: z
        .object({
          deliveryRadiusKm: z.coerce.number().nonnegative().optional(),
          centerLat: z.coerce.number().optional(),
          centerLng: z.coerce.number().optional(),
          minOrderAmount: z.coerce.number().nonnegative().optional(),
          deliveryFee: z.coerce.number().nonnegative().optional(),
          isOpen: z.boolean().optional(),
        })
        .partial()
        .optional(),
    })
    .partial(),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const changeUserRoleSchema = z.object({
  body: z.object({
    role: z.enum(['customer', 'delivery_partner', 'admin', 'staff']),
  }),
  params: z.object({
    id: z.string().transform(Number),
  }),
});

const getUserDetailSchema = z.object({
  params: z.object({ id: idParam }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
});

const toggleUserStatusSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({
    is_active: z.boolean(),
  }),
  query: z.object({}).optional(),
});

const updateDeliveryZoneSchema = z.object({
  body: z.object({
    radiusKm: z.number().min(0.5).max(100),
    centerLat: z.number(),
    centerLng: z.number(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const toggleStoreOpenSchema = z.object({
  body: z.object({}).optional(),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  dashboardSchema,
  listCustomersSchema,
  getUserDetailSchema,
  toggleUserStatusSchema,
  listDeliveryPartnersSchema,
  toggleDeliveryPartnerSchema,
  listOrdersCompatSchema,
  patchOrderCompatSchema,
  assignRiderToOrderSchema,
  listCompatSchema,
  upsertCategoryCompatSchema,
  upsertProductCompatSchema,
  patchDeliveryPartnerCompatSchema,
  deleteProductCompatSchema,
  updateStockSchema,
  deleteCategorySchema,
  upsertBannerSchema,
  deleteBannerSchema,
  updateSettingsSchema,
  changeUserRoleSchema,
  updateDeliveryZoneSchema,
  toggleStoreOpenSchema,
};
