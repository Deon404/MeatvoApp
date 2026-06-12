const { z } = require('zod');

const normalizePhone = (raw) => {
  const input = String(raw || '').trim();
  if (!input) return input;
  if (input.startsWith('+')) return input.replace(/\s/g, '');

  const defaultCc = String(process.env.DEFAULT_COUNTRY_CODE || '+91').trim();
  const cc = defaultCc.startsWith('+') ? defaultCc : `+${defaultCc}`;
  let digits = input.replace(/\D/g, '');

  // 09876543210 → 9876543210 (India local with leading 0)
  if (digits.length === 11 && digits.startsWith('0')) {
    digits = digits.slice(1);
  }
  // 919876543210 → +919876543210
  if (digits.length === 12 && digits.startsWith('91')) {
    return `+${digits}`;
  }
  if (/^\d{10}$/.test(digits)) return `${cc}${digits}`;
  return input; // fall back; final regex validation will catch it
};

const OTP_LENGTH = Number(process.env.MSG91_OTP_LENGTH || process.env.OTP_LENGTH || 6);

/** OTP codes are numeric; SMS may drop leading zeros in display. */
const normalizeOtp = (raw) => {
  const digits = String(raw || '').trim().replace(/\D/g, '');
  const maxLen = Math.max(4, OTP_LENGTH);
  if (!new RegExp(`^\\d{1,${maxLen}}$`).test(digits)) return digits;
  return digits.padStart(OTP_LENGTH, '0');
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
    resend: z.boolean().optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const verifyOtpSchema = z.object({
  body: z.object({
    phone: e164Phone,
    otp: z.preprocess(
      normalizeOtp,
      z.string().regex(new RegExp(`^\\d{${OTP_LENGTH}}$`), `OTP must be ${OTP_LENGTH} digits`),
    ),
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

const enableMfaSchema = z.object({
  body: z.object({
    secret: z.string().min(32, 'Invalid secret format'),
    token: z.string().regex(/^\d{6}$/, 'Token must be 6 digits'),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

module.exports = {
  sendOtpSchema,
  verifyOtpSchema,
  refreshTokenSchema,
  enableMfaSchema,
  normalizePhone,
  normalizeOtp,
};
