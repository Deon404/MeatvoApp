const { z } = require('zod');

const normalizePhone = (raw) => {
  const input = String(raw || '').trim();
  if (!input) return input;
  if (input.startsWith('+')) return input;

  // Accept common local formats in web UIs (e.g. "9999999999") and prefix with default country code.
  const digits = input.replace(/\D/g, '');
  const defaultCc = String(process.env.DEFAULT_COUNTRY_CODE || '+91').trim();
  const cc = defaultCc.startsWith('+') ? defaultCc : `+${defaultCc}`;
  if (/^\d{10}$/.test(digits)) return `${cc}${digits}`;
  return input; // fall back; final regex validation will catch it
};

const e164Phone = z.preprocess(
  normalizePhone,
  z
    .string()
    .trim()
    .regex(/^\+[1-9]\d{1,14}$/, 'Phone must be E.164 (e.g. +919999999999)')
);

const sendOtpSchema = z.object({
  body: z.object({
    phone: e164Phone,
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const verifyOtpSchema = z.object({
  body: z.object({
    phone: e164Phone,
    otp: z.string().trim().regex(/^\d{4}$/, 'OTP must be 4 digits'),
    mfaToken: z.string().trim().regex(/^\d{6}$/, 'MFA token must be 6 digits').optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const refreshTokenSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  sendOtpSchema,
  verifyOtpSchema,
  refreshTokenSchema,
};
