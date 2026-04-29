const { z } = require('zod');

const listCategoriesSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const listProductsSchema = z.object({
  query: z
    .object({
      limit: z.coerce.number().int().positive().max(200).optional(),
      skip: z.coerce.number().int().nonnegative().optional(),
      categoryId: z.coerce.number().int().positive().optional(),
      q: z.string().trim().min(1).optional(),
    })
    .partial()
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

module.exports = { listCategoriesSchema, listProductsSchema };

