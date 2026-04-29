const { z } = require('zod');

const cartItemSchema = z.object({
  productId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0, 'Invalid product ID'),
  quantity: z.coerce.number().int().min(1).max(10),
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
  body: z.object({
    productId: cartItemSchema.shape.productId,
    quantity: z.coerce.number().int().min(0).max(10),
  }),
});

const removeFromCartSchema = z.object({
  params: z.object({
    productId: z.union([z.string(), z.number()]).transform((v) => String(v).trim()).refine(id => Number(id) > 0)
  })
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

