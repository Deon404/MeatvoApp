const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const listProductsSchema = z.object({
  query: z
    .object({
      page: z.coerce.number().int().positive().optional(),
      limit: z.coerce.number().int().positive().max(100).min(1).optional(),
      categoryId: z.coerce.number().int().positive().optional(),
      category: z.coerce.number().int().positive().optional(),
      min_price: z.coerce.number().nonnegative().optional(),
      max_price: z.coerce.number().nonnegative().optional(),
      q: z.string().trim().min(1).optional(),
      search: z.string().trim().min(1).optional(),
      includeInactive: z
        .enum(['true', 'false'])
        .optional()
        .transform((v) => v === 'true'),
    })
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const getProductByIdSchema = z.object({
  params: z.object({ id: idParam }),
});

const getCategoriesSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const getFeaturedProductsSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const searchProductsSchema = z.object({
  query: z.object({
    q: z.string().trim().min(2).max(100)
  }).partial().optional(),
});

const productBody = z.object({
  category_id: z.coerce.number().int().positive().nullable().optional(),
  name: z.string().trim().min(3).max(100),
  description: z.string().trim().max(500).optional().nullable(),
  price: z.coerce.number().positive().max(10000),
  mrp: z.coerce.number().nonnegative().optional().nullable(),
  image_url: z.string().trim().url().optional().nullable(),
  stock: z.coerce.number().int().nonnegative().optional(),
  unit: z.string().trim().max(20).optional().nullable(),
  active: z.boolean().optional(),
});

const createProductSchema = z.object({
  body: productBody,
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateProductSchema = z.object({
  params: z.object({ id: idParam }),
  body: productBody.partial(),
  query: z.object({}).optional(),
});

const deleteProductSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  listProductsSchema,
  getProductByIdSchema,
  getCategoriesSchema,
  getFeaturedProductsSchema,
  searchProductsSchema,
  createProductSchema,
  updateProductSchema,
  deleteProductSchema,
};

