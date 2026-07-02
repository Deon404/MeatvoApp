const { z } = require('zod');

const initiatePaymentSchema = z.object({
  body: z.object({
    orderId: z.coerce.number().int().positive(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const getPaymentStatusSchema = z.object({
  params: z.object({
    orderId: z.coerce.number().int().positive(),
  }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const verifyPaymentSchema = z.object({
  body: z.object({
    orderId: z.coerce.number().int().positive(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  initiatePaymentSchema,
  getPaymentStatusSchema,
  verifyPaymentSchema,
};
