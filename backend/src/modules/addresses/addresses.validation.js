const { z } = require('zod');

const idParam = z.coerce.number().int().positive();

const DEFAULT_LAT = 23.7957;
const DEFAULT_LNG = 86.4304;

const ALLOWED_ADDRESS_CHARS = /^[a-zA-Z0-9\s\-/#.,()'&]+$/;

const looksLikeGibberish = (value) => {
  const trimmed = String(value ?? '').trim();
  if (!trimmed) return false;
  if (/^\d+$/.test(trimmed)) return false;

  const lettersOnly = trimmed.toLowerCase().replace(/[^a-z]/g, '');
  if (!lettersOnly) return false;

  const vowels = (lettersOnly.match(/[aeiou]/g) || []).length;
  if (lettersOnly.length >= 5 && vowels === 0) return true;
  if (lettersOnly.length >= 6 && vowels / lettersOnly.length < 0.12) return true;
  if (/[bcdfghjklmnpqrstvwxyz]{4,}/.test(lettersOnly)) return true;
  if (/(.)\1{2,}/.test(lettersOnly)) return true;
  return false;
};

const isMeaningfulAddressLine = (value) => {
  const v = String(value ?? '').trim();
  if (v.length < 2) return false;
  if (!ALLOWED_ADDRESS_CHARS.test(v)) return false;
  if (/\d/.test(v)) return true;
  if (
    /\b(flat|flt|house|h\.?\s*no|plot|door|room|building|bldg|blk|block|apt|apartment|unit|shop|shed|wing|tower|twr|sector|sec)\b/i.test(
      v
    )
  ) {
    return true;
  }
  if (v.length <= 3 && /^[a-zA-Z0-9]+$/.test(v)) return true;
  if (v.includes(' ') && !looksLikeGibberish(v)) return true;
  return !looksLikeGibberish(v) && v.length >= 5;
};

const isMeaningfulLandmark = (value) => {
  const v = String(value ?? '').trim();
  if (!v) return true;
  if (v.length < 3) return false;
  if (!ALLOWED_ADDRESS_CHARS.test(v)) return false;
  if (looksLikeGibberish(v)) return false;
  if (/\d/.test(v)) return true;
  if (
    /\b(near|opposite|behind|beside|next to|landmark|market|temple|school|hospital|mall|store|park|chowk|mandir|masjid|church|bus stop|metro|station|bank|hotel|restaurant|petrol|pump|colony|gate|main road)\b/i.test(
      v
    )
  ) {
    return true;
  }
  const words = v.split(/\s+/).filter((w) => w.length >= 2);
  return words.length >= 2;
};

const normalizeLabel = (label) => {
  const raw = String(label ?? 'home').toLowerCase();
  const s = raw.includes('.') ? raw.split('.').pop() : raw;
  if (['home', 'work', 'other'].includes(s)) return s;
  return 'home';
};

const addressBodyShape = {
  label: z.union([z.string(), z.number()]).optional(),
  addressLine: z.string().trim().min(5).max(300).optional(),
  addressLine1: z.string().trim().min(5).max(300).optional(),
  addressLine2: z.string().trim().max(300).optional().nullable(),
  city: z.string().trim().max(100).optional(),
  state: z.string().trim().max(100).optional(),
  pincode: z.string().trim().max(10).optional(),
  landmark: z.string().trim().max(120).optional().nullable(),
  lat: z.coerce.number().optional(),
  lng: z.coerce.number().optional(),
  latitude: z.coerce.number().optional(),
  longitude: z.coerce.number().optional(),
  isDefault: z.boolean().optional(),
};

const transformAddressBody = (b, { requireLine = true } = {}) => {
  const hasLine = b.addressLine1 !== undefined || b.addressLine !== undefined;
  const addressLine1 = hasLine ? (b.addressLine1 || b.addressLine || '').trim() : undefined;
  const hasCoords =
    b.lat !== undefined ||
    b.lng !== undefined ||
    b.latitude !== undefined ||
    b.longitude !== undefined;
  const lat = hasCoords ? b.lat ?? b.latitude ?? DEFAULT_LAT : undefined;
  const lng = hasCoords ? b.lng ?? b.longitude ?? DEFAULT_LNG : undefined;
  return {
    label: b.label !== undefined ? normalizeLabel(b.label) : undefined,
    addressLine1: requireLine && !hasLine ? (b.addressLine1 || b.addressLine || '').trim() : addressLine1,
    addressLine2: b.addressLine2 !== undefined ? b.addressLine2?.trim() || null : undefined,
    city: b.city !== undefined ? (b.city || 'Dhanbad').trim() : undefined,
    state: b.state !== undefined ? (b.state || 'Jharkhand').trim() : undefined,
    pincode: b.pincode !== undefined ? (b.pincode || '').trim() : undefined,
    landmark: b.landmark !== undefined ? b.landmark?.trim() || null : undefined,
    lat,
    lng,
    isDefault: b.isDefault !== undefined ? Boolean(b.isDefault) : undefined,
  };
};

const listAddressesSchema = z.object({
  query: z.object({}).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
});

const createAddressSchema = z.object({
  body: z
    .object(addressBodyShape)
    .transform((b) => ({
      label: normalizeLabel(b.label),
      addressLine1: (b.addressLine1 || b.addressLine || '').trim(),
      addressLine2: b.addressLine2?.trim() || null,
      city: (b.city || 'Dhanbad').trim(),
      state: (b.state || 'Jharkhand').trim(),
      pincode: (b.pincode || '').trim(),
      landmark: b.landmark?.trim() || null,
      lat: b.lat ?? b.latitude ?? DEFAULT_LAT,
      lng: b.lng ?? b.longitude ?? DEFAULT_LNG,
      isDefault: Boolean(b.isDefault),
    }))
    .refine((b) => b.addressLine1.length >= 5, {
      message: 'Address line is required (min 5 characters)',
      path: ['addressLine1'],
    })
    .refine((b) => isMeaningfulAddressLine(b.addressLine1), {
      message: 'Please enter a valid house / flat / building address',
      path: ['addressLine1'],
    })
    .refine((b) => isMeaningfulLandmark(b.landmark), {
      message: 'Please enter a valid nearby landmark',
      path: ['landmark'],
    }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

const updateAddressSchema = z.object({
  params: z.object({ id: idParam }),
  body: z
    .object(addressBodyShape)
    .transform((b) => transformAddressBody(b, { requireLine: false }))
    .refine(
      (b) => b.addressLine1 === undefined || b.addressLine1.length >= 5,
      {
        message: 'Address line must be at least 5 characters when provided',
        path: ['addressLine1'],
      }
    )
    .refine(
      (b) => b.addressLine1 === undefined || isMeaningfulAddressLine(b.addressLine1),
      {
        message: 'Please enter a valid house / flat / building address',
        path: ['addressLine1'],
      }
    )
    .refine(
      (b) => b.landmark === undefined || b.landmark === null || isMeaningfulLandmark(b.landmark),
      {
        message: 'Please enter a valid nearby landmark',
        path: ['landmark'],
      }
    ),
  query: z.object({}).optional(),
});

const setDefaultAddressSchema = z.object({
  params: z.object({ id: idParam }),
  body: z.object({ isDefault: z.literal(true).optional() }).optional(),
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
  updateAddressSchema,
  setDefaultAddressSchema,
  deleteAddressSchema,
};
