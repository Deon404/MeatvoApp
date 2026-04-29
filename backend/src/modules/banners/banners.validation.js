const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const listBannersSchema = z.object({
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

const createBannerSchema = z.object({
  body: z.object({
    image_url: z.string().trim().min(1),
    active: z.boolean().optional(),
    sort_order: z.coerce.number().int().optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const deleteBannerSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  listBannersSchema,
  createBannerSchema,
  deleteBannerSchema,
};

