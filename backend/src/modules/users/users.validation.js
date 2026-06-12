const { z } = require('zod');

const fcmTokenSchema = z.object({
  body: z.object({
    fcm_token: z.string().min(1, 'FCM token is required'),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = { fcmTokenSchema };
