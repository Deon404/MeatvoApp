const { z } = require('zod');

const fcmTokenSchema = z.object({
  body: z.object({
    fcm_token: z.string().min(1, 'FCM token is required'),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateProfileSchema = z.object({
  body: z
    .object({
      name: z.string().trim().min(1).max(120).optional(),
      email: z.string().trim().email().optional().nullable(),
      profile_image_url: z.string().trim().url().optional().nullable(),
    })
    .refine((body) => Object.keys(body).length > 0, {
      message: 'At least one field is required',
    }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const wishlistProductSchema = z.object({
  body: z.object({
    product_id: z.coerce.number().int().positive(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const submitReviewSchema = z.object({
  body: z.object({
    order_id: z.coerce.number().int().positive(),
    rider_rating: z.coerce.number().int().min(1).max(5).optional(),
    product_quality_rating: z.coerce.number().int().min(1).max(5).optional(),
    delivery_speed_rating: z.coerce.number().int().min(1).max(5).optional(),
    feedback: z.string().trim().max(1000).optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  fcmTokenSchema,
  updateProfileSchema,
  wishlistProductSchema,
  submitReviewSchema,
};
