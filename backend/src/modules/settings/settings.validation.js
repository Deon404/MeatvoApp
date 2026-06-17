const { z } = require('zod');

const themeSchema = z.object({
  colors: z.record(z.string().trim().min(1), z.string().trim().min(1)).optional().default({}),
  navbarStyle: z.string().trim().optional().nullable(),
});

const bannerSchema = z.object({
  title: z.string().trim().optional().nullable(),
  subtitle: z.string().trim().optional().nullable(),
  buttonText: z.string().trim().optional().nullable(),
  imageUrl: z.string().trim().optional().nullable(),
  gradientStart: z.string().trim().optional().nullable(),
  gradientEnd: z.string().trim().optional().nullable(),
});

const getSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const putThemeSchema = z.object({
  body: themeSchema,
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const putBannerSchema = z.object({
  body: bannerSchema,
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const putAppInfoSchema = z.object({
  body: z.object({
    appVersion: z.string().trim().min(1).max(20),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = { getSchema, putThemeSchema, putBannerSchema, putAppInfoSchema };

