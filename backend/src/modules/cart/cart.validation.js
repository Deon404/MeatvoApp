const { z } = require('zod');

const cartItemSchema = z.object({
  productId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0, 'Invalid product ID'),
  quantity: z.coerce.number().int().min(1).max(10),
  variantId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).optional(),
  weightGrams: z.coerce.number().int().min(50).max(50000).optional(),
});

const getCartSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const addToCartSchema = z.object({
  body: cartItemSchema,
});

const updateCartItemSchema = z.object({
  params: z.object({
    itemId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0, 'Invalid product ID').optional(),
    productId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0, 'Invalid product ID').optional(),
  }).optional(),
  body: z.object({
    productId: cartItemSchema.shape.productId.optional(),
    quantity: z.coerce.number().int().min(0).max(10),
    variantId: cartItemSchema.shape.variantId,
    weightGrams: cartItemSchema.shape.weightGrams,
  }),
}).superRefine((data, ctx) => {
  const bodyId = data.body?.productId;
  const paramId = data.params?.itemId || data.params?.productId;
  if (!bodyId && !paramId) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['body', 'productId'],
      message: 'productId or itemId is required',
    });
  }
});

const removeFromCartSchema = z.object({
  params: z.object({
    itemId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0).optional(),
    productId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0).optional()
  })
}).superRefine((data, ctx) => {
  const paramId = data.params?.itemId || data.params?.productId;
  if (!paramId) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['params', 'itemId'],
      message: 'itemId or productId is required',
    });
  }
});

const clearCartSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const getCartCountSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

module.exports = {
  getCartSchema,
  addToCartSchema,
  updateCartItemSchema,
  removeFromCartSchema,
  clearCartSchema,
  getCartCountSchema
};
