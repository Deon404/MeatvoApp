const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const listCategoriesSchema = z.object({
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

const categoryBody = z.object({
  name: z.string().trim().min(1),
  image_url: z.string().trim().optional().nullable(),
  active: z.boolean().optional(),
});

const createCategorySchema = z.object({
  body: categoryBody,
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateCategorySchema = z.object({
  params: z.object({ id: idParam }),
  body: categoryBody.partial(),
  query: z.object({}).optional(),
});

const deleteCategorySchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  listCategoriesSchema,
  createCategorySchema,
  updateCategorySchema,
  deleteCategorySchema,
};

