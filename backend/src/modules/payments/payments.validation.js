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
  body: z
    .object({
      transactionId: z.string().trim().min(1).optional(),
      merchantTransactionId: z.string().trim().min(1).optional(),
    })
    .refine(
      (body) => Boolean(body.transactionId || body.merchantTransactionId),
      { message: 'transactionId or merchantTransactionId is required' }
    ),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  initiatePaymentSchema,
  getPaymentStatusSchema,
  verifyPaymentSchema,
};
