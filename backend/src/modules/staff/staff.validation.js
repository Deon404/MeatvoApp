const { z } = require('zod');

const listKitchenOrdersSchema = z.object({
  query: z
    .object({
      status: z.enum(['CONFIRMED', 'PACKING_STARTED']).optional(),
      limit: z.coerce.number().int().min(1).max(200).optional(),
      offset: z.coerce.number().int().min(0).optional(),
    })
    .optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

module.exports = {
  listKitchenOrdersSchema,
};
