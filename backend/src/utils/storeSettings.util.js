const { query } = require('../db/postgres');
const { repairAppSettingsSchema } = require('../db/appSettings');
const { resolveStoreAvailability } = require('./storeHours.util');

const DEFAULT_STORE_SETTINGS = {
  delivery_radius_km: 8.0,
  center_lat: 23.6583,
  center_lng: 86.1764,
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

const DB_READ_TIMEOUT_MS = 5000;

let cachedMergedSettings = null;
let cachedMergedAt = 0;
let schemaRepairScheduled = false;

const invalidateStoreSettingsCache = () => {
  cachedMergedSettings = null;
  cachedMergedAt = 0;
};

const queryWithTimeout = (text, params = [], timeoutMs = DB_READ_TIMEOUT_MS) =>
  Promise.race([
    query(text, params),
    new Promise((_, reject) =>
      setTimeout(
        () => reject(Object.assign(new Error('DB query timeout'), { code: 'ETIMEOUT' })),
        timeoutMs
      )
    ),
  ]);

const scheduleSchemaRepair = () => {
  if (schemaRepairScheduled) return;
  schemaRepairScheduled = true;
  repairAppSettingsSchema()
    .catch(() => {})
    .finally(() => {
      schemaRepairScheduled = false;
    });
};

const buildMergedSettings = (operational = {}, storeRow = null) => {
  const manualOpen = resolveManualOpen(operational, storeRow);
  const availability = resolveStoreAvailability({
    manualOpen,
    storeOpenTime: operational.store_open_time ?? null,
    storeCloseTime: operational.store_close_time ?? null,
  });

  return {
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
};

const readOperationalSettings = async () => {
  try {
    const { rows } = await queryWithTimeout(
      `SELECT delivery_charge, min_order_amount, store_open,
              store_open_time, store_close_time, delivery_radius_km
       FROM app_settings
       ORDER BY updated_at DESC NULLS LAST
       LIMIT 1`
    );
    return rows[0] || {};
  } catch (err) {
    if (err?.code === '42P01') return {};
    if (err?.code === '42703') {
      scheduleSchemaRepair();
      return {};
    }
    if (err?.code === 'ETIMEOUT') return {};
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

let storeSettingsTableEnsureScheduled = false;

const scheduleStoreSettingsTableEnsure = () => {
  if (storeSettingsTableEnsureScheduled) return;
  storeSettingsTableEnsureScheduled = true;
  query(STORE_SETTINGS_DDL)
    .catch(() => {})
    .finally(() => {
      storeSettingsTableEnsureScheduled = false;
    });
};

const ensureStoreSettingsTable = async () => {
  await query(STORE_SETTINGS_DDL);
};

const readStoreSettingsRow = async () => {
  try {
    const { rows } = await queryWithTimeout(
      `SELECT delivery_radius_km, center_lat, center_lng,
              min_order_amount, delivery_fee, is_open
       FROM store_settings
       LIMIT 1`
    );
    return rows[0] || null;
  } catch (err) {
    if (err?.code === '42P01') {
      scheduleStoreSettingsTableEnsure();
      return null;
    }
    if (err?.code === 'ETIMEOUT') return null;
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

  try {
    const reads = Promise.all([readOperationalSettings(), readStoreSettingsRow()]);
    const timeout = new Promise((_, reject) =>
      setTimeout(
        () => reject(Object.assign(new Error('Store settings read timeout'), { code: 'ETIMEOUT' })),
        DB_READ_TIMEOUT_MS
      )
    );
    const [operational, storeRow] = await Promise.race([reads, timeout]);
    const merged = buildMergedSettings(operational, storeRow);
    cachedMergedSettings = merged;
    cachedMergedAt = now;
    return merged;
  } catch {
    if (cachedMergedSettings) {
      return cachedMergedSettings;
    }
    return buildMergedSettings({}, null);
  }
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
     WHERE ctid = (
       SELECT ctid FROM store_settings
       LIMIT 1
     )`,
    [
      deliveryFee ?? null,
      minOrder ?? null,
      radius ?? null,
      isOpen ?? null,
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
    `SELECT ctid FROM app_settings
     ORDER BY updated_at DESC NULLS LAST
     LIMIT 1`
  );

  if (existing[0]) {
    await query(
      `UPDATE app_settings
       SET store_open = $1, updated_at = NOW()
       WHERE ctid = $2`,
      [nextManual, existing[0].ctid]
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
  queryWithTimeout,
  scheduleSchemaRepair,
  ensureStoreSettingsTable,
  readOperationalSettings,
  readStoreSettingsRow,
  getMergedStoreSettings,
  invalidateStoreSettingsCache,
  syncOperationalToStoreSettings,
  toggleManualStoreOpen,
  resolveManualOpen,
};
