const { query } = require('../db/postgres');
const { repairAppSettingsSchema } = require('../db/appSettings');
const { resolveStoreAvailability } = require('./storeHours.util');

const DEFAULT_STORE_SETTINGS = {
  delivery_radius_km: 8.0,
  center_lat: 0,
  center_lng: 0,
  min_order_amount: 150.0,
  delivery_fee: 30.0,
  is_open: true,
  manual_open: true,
  within_hours: true,
  store_open_time: '09:00',
  store_close_time: '22:00',
  closed_reason: null,
  closed_message: null,
  next_open_display: null,
};

const STORE_SETTINGS_CACHE_TTL_MS = Number(
  process.env.STORE_SETTINGS_CACHE_TTL_MS || 60_000
);

let cachedMergedSettings = null;
let cachedMergedAt = 0;

const invalidateStoreSettingsCache = () => {
  cachedMergedSettings = null;
  cachedMergedAt = 0;
};

const readOperationalSettings = async () => {
  try {
    const { rows } = await query(
      `SELECT delivery_charge, min_order_amount, store_open,
              store_open_time, store_close_time, delivery_radius_km
       FROM app_settings
       ORDER BY id
       LIMIT 1`
    );
    return rows[0] || {};
  } catch (err) {
    if (err?.code === '42P01') return {};
    if (err?.code === '42703') {
      await repairAppSettingsSchema();
      return readOperationalSettings();
    }
    throw err;
  }
};

const STORE_SETTINGS_DDL = `
  CREATE TABLE IF NOT EXISTS store_settings (
    id SERIAL PRIMARY KEY,
    delivery_radius_km DECIMAL(5,2) DEFAULT 5.0,
    center_lat DECIMAL(10,7) DEFAULT 0,
    center_lng DECIMAL(10,7) DEFAULT 0,
    min_order_amount DECIMAL(10,2) DEFAULT 150.0,
    delivery_fee DECIMAL(10,2) DEFAULT 30.0,
    is_open BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW()
  )
`;

const ensureStoreSettingsTable = async () => {
  await query(STORE_SETTINGS_DDL);
};

const readStoreSettingsRow = async () => {
  try {
    const { rows } = await query(
      `SELECT id, delivery_radius_km, center_lat, center_lng,
              min_order_amount, delivery_fee, is_open
       FROM store_settings
       LIMIT 1`
    );
    return rows[0] || null;
  } catch (err) {
    if (err?.code === '42P01') {
      await ensureStoreSettingsTable();
      return null;
    }
    throw err;
  }
};

const resolveManualOpen = (operational, storeRow) => {
  if (operational.store_open !== undefined && operational.store_open !== null) {
    return Boolean(operational.store_open);
  }
  if (storeRow?.is_open !== undefined && storeRow?.is_open !== null) {
    return Boolean(storeRow.is_open);
  }
  return DEFAULT_STORE_SETTINGS.manual_open;
};

/**
 * Merges admin operational settings (app_settings) with geo/store row (store_settings).
 * Applies manual toggle + configured store hours (IST) for effective is_open.
 */
const getMergedStoreSettings = async ({ forceRefresh = false } = {}) => {
  const now = Date.now();
  if (
    !forceRefresh &&
    cachedMergedSettings &&
    now - cachedMergedAt < STORE_SETTINGS_CACHE_TTL_MS
  ) {
    return cachedMergedSettings;
  }

  const [operational, storeRow] = await Promise.all([
    readOperationalSettings(),
    readStoreSettingsRow(),
  ]);

  const manualOpen = resolveManualOpen(operational, storeRow);
  const availability = resolveStoreAvailability({
    manualOpen,
    storeOpenTime: operational.store_open_time ?? null,
    storeCloseTime: operational.store_close_time ?? null,
  });

  const merged = {
    delivery_radius_km: Number(
      operational.delivery_radius_km ??
        storeRow?.delivery_radius_km ??
        DEFAULT_STORE_SETTINGS.delivery_radius_km
    ),
    center_lat: Number(storeRow?.center_lat ?? DEFAULT_STORE_SETTINGS.center_lat),
    center_lng: Number(storeRow?.center_lng ?? DEFAULT_STORE_SETTINGS.center_lng),
    min_order_amount: Number(
      operational.min_order_amount ??
        storeRow?.min_order_amount ??
        DEFAULT_STORE_SETTINGS.min_order_amount
    ),
    delivery_fee: Number(
      operational.delivery_charge ??
        storeRow?.delivery_fee ??
        DEFAULT_STORE_SETTINGS.delivery_fee
    ),
    manual_open: availability.manual_open,
    within_hours: availability.within_hours,
    store_open_time: availability.store_open_time,
    store_close_time: availability.store_close_time,
    is_open: availability.is_open,
    closed_reason: availability.closed_reason,
    closed_message: availability.closed_message,
    next_open_display: availability.next_open_display,
  };

  cachedMergedSettings = merged;
  cachedMergedAt = now;
  return merged;
};

/**
 * Keeps store_settings in sync when admin updates operational settings.
 */
const syncOperationalToStoreSettings = async (operational = {}) => {
  await ensureStoreSettingsTable();
  const existing = await readStoreSettingsRow();
  const deliveryFee =
    operational.delivery_charge !== undefined
      ? Number(operational.delivery_charge)
      : undefined;
  const minOrder =
    operational.min_order_amount !== undefined
      ? Number(operational.min_order_amount)
      : undefined;
  const radius =
    operational.delivery_radius_km !== undefined
      ? Number(operational.delivery_radius_km)
      : undefined;
  const isOpen =
    operational.store_open !== undefined ? Boolean(operational.store_open) : undefined;

  if (!existing) {
    await query(
      `INSERT INTO store_settings (
         delivery_radius_km, min_order_amount, delivery_fee, is_open, updated_at
       )
       VALUES ($1, $2, $3, $4, NOW())`,
      [
        radius ?? DEFAULT_STORE_SETTINGS.delivery_radius_km,
        minOrder ?? DEFAULT_STORE_SETTINGS.min_order_amount,
        deliveryFee ?? DEFAULT_STORE_SETTINGS.delivery_fee,
        isOpen ?? DEFAULT_STORE_SETTINGS.manual_open,
      ]
    );
    invalidateStoreSettingsCache();
    return;
  }

  await query(
    `UPDATE store_settings
     SET delivery_fee = COALESCE($1, delivery_fee),
         min_order_amount = COALESCE($2, min_order_amount),
         delivery_radius_km = COALESCE($3, delivery_radius_km),
         is_open = COALESCE($4, is_open),
         updated_at = NOW()
     WHERE id = $5`,
    [
      deliveryFee ?? null,
      minOrder ?? null,
      radius ?? null,
      isOpen ?? null,
      existing.id,
    ]
  );
  invalidateStoreSettingsCache();
};

const toggleManualStoreOpen = async () => {
  const operational = await readOperationalSettings();
  const storeRow = await readStoreSettingsRow();
  const currentManual = resolveManualOpen(operational, storeRow);
  const nextManual = !currentManual;

  const { rows: existing } = await query(
    'SELECT id FROM app_settings ORDER BY id LIMIT 1'
  );

  if (existing[0]) {
    await query(
      `UPDATE app_settings
       SET store_open = $1, updated_at = NOW()
       WHERE id = $2`,
      [nextManual, existing[0].id]
    );
  } else {
    await query(
      `INSERT INTO app_settings (store_open, updated_at)
       VALUES ($1, NOW())`,
      [nextManual]
    );
  }

  await syncOperationalToStoreSettings({ store_open: nextManual });
  return getMergedStoreSettings({ forceRefresh: true });
};

module.exports = {
  DEFAULT_STORE_SETTINGS,
  ensureStoreSettingsTable,
  readOperationalSettings,
  readStoreSettingsRow,
  getMergedStoreSettings,
  invalidateStoreSettingsCache,
  syncOperationalToStoreSettings,
  toggleManualStoreOpen,
  resolveManualOpen,
};
