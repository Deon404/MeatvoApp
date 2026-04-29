const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const listAddressesSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const createAddressSchema = z.object({
  body: z.object({
    label: z.string().trim().min(1).max(40),
    addressLine: z.string().trim().min(5).max(300),
    landmark: z.string().trim().max(120).optional().nullable(),
    lat: z.coerce.number(),
    lng: z.coerce.number(),
    isDefault: z.boolean().optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const deleteAddressSchema = z.object({
  params: z.object({ id: idParam }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
});

module.exports = {
  listAddressesSchema,
  createAddressSchema,
  deleteAddressSchema,
};
