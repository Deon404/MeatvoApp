const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const { emitToAll } = require('../../socket/socket');
const { isWithinDeliveryZone } = require('../../utils/distance.util');
const { calculateExpressETA } = require('../../utils/eta-calculator');
const {
  DEFAULT_STORE_SETTINGS,
  getMergedStoreSettings,
  queryWithTimeout,
  scheduleSchemaRepair,
} = require('../../utils/storeSettings.util');

const DEFAULT_THEME = {
  colors: {
    primaryColor: '#d32f2f',
    secondaryColor: '#111827',
    bgColor: '#ffffff',
    textColor: '#111827',
    navbarActiveColor: '#d32f2f',
    buttonColor: '#d32f2f',
    buttonTextColor: '#ffffff',
  },
  navbarStyle: 'default',
};

const DEFAULT_BANNER = {
  title: 'Fresh Meat\nDelivered Fast',
  subtitle: 'Order chicken, eggs & more',
  buttonText: 'Order Now',
  imageUrl: '',
  gradientStart: '#667eea',
  gradientEnd: '#764ba2',
};

const DEFAULT_APP_INFO = {
  appVersion: process.env.APP_VERSION || '1.0.0',
};

const resolveAppInfo = (raw) => {
  const version = String(
    raw?.appVersion ?? raw?.app_version ?? DEFAULT_APP_INFO.appVersion,
  ).trim();
  return {
    appVersion: version || DEFAULT_APP_INFO.appVersion,
  };
};

// ─── Generic key-value settings helpers ──────────────────────────────────────

const APP_SETTINGS_DDL = `
  CREATE TABLE IF NOT EXISTS app_settings (
    id SERIAL PRIMARY KEY,
    delivery_charge NUMERIC(10,2) DEFAULT 30,
    min_order_amount NUMERIC(10,2) DEFAULT 150,
    store_open BOOLEAN DEFAULT true,
    store_open_time TIME,
    store_close_time TIME,
    delivery_radius_km NUMERIC(5,2) DEFAULT 8.0,
    value JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )
`;

let appSettingsTableCreateScheduled = false;

const scheduleAppSettingsTableCreate = () => {
  if (appSettingsTableCreateScheduled) return;
  appSettingsTableCreateScheduled = true;
  query(APP_SETTINGS_DDL)
    .catch(() => {})
    .finally(() => {
      appSettingsTableCreateScheduled = false;
    });
};

const getSetting = async (key) => {
  try {
    const { rows } = await queryWithTimeout(
      `SELECT value->$1 AS value
       FROM app_settings
       ORDER BY updated_at DESC NULLS LAST
       LIMIT 1`,
      [key]
    );
    return rows[0]?.value || null;
  } catch (err) {
    if (err?.code === '42P01') return null;
    if (err?.code === '42703') {
      scheduleSchemaRepair();
      return null;
    }
    if (err?.code === 'ETIMEOUT') return null;
    throw err;
  }
};

const putSetting = async (key, value) => {
  try {
    const { rows: existing } = await queryWithTimeout(
      `SELECT ctid FROM app_settings
       ORDER BY updated_at DESC NULLS LAST
       LIMIT 1`
    );
    if (existing[0]) {
      const { rows } = await queryWithTimeout(
        `UPDATE app_settings
         SET value = jsonb_set(COALESCE(value, '{}'::jsonb), ARRAY[$1], $2::jsonb, true),
             updated_at = NOW()
         WHERE ctid = $3
         RETURNING value->$1 AS value`,
        [key, value, existing[0].ctid]
      );
      return rows[0]?.value || value;
    }

    const { rows } = await queryWithTimeout(
      `INSERT INTO app_settings (value, updated_at)
       VALUES (jsonb_build_object($1, $2::jsonb), NOW())
       RETURNING value->$1 AS value`,
      [key, value]
    );
    return rows[0]?.value || value;
  } catch (err) {
    if (err?.code === '42703') {
      scheduleSchemaRepair();
      return value;
    }
    if (err?.code === '42P01') {
      scheduleAppSettingsTableCreate();
      scheduleSchemaRepair();
      return value;
    }
    if (err?.code === 'ETIMEOUT') return value;
    throw err;
  }
};

// ─── Store settings helpers (store_settings table) ────────────────────────────

/**
 * Reads merged store settings (admin app_settings + store_settings geo row).
 */
const getStoreSettings = async () => getMergedStoreSettings();

// ─── Existing theme / banner controllers ─────────────────────────────────────

const getTheme = asyncHandler(async (req, res) => {
  let v = null;
  try {
    v = await getSetting('theme');
  } catch (err) {
    logger.warn('settings_get_failed', { key: 'theme', message: err?.message, code: err?.code });
  }
  v = v || DEFAULT_THEME;
  return ok(res, v, 'Theme');
});

const getBanner = asyncHandler(async (req, res) => {
  let v = null;
  try {
    v = await getSetting('banner');
  } catch (err) {
    logger.warn('settings_get_failed', { key: 'banner', message: err?.message, code: err?.code });
  }
  v = v || DEFAULT_BANNER;
  return ok(res, v, 'Banner');
});

const getAppInfo = asyncHandler(async (req, res) => {
  let v = null;
  try {
    v = await getSetting('appInfo');
  } catch (err) {
    logger.warn('settings_get_failed', { key: 'appInfo', message: err?.message, code: err?.code });
  }
  return ok(res, resolveAppInfo(v), 'App info');
});

const putTheme = asyncHandler(async (req, res) => {
  const saved = await putSetting('theme', req.validated.body);
  emitToAll('settings:theme', { theme: saved });
  return ok(res, saved, 'Theme updated');
});

const putBanner = asyncHandler(async (req, res) => {
  const saved = await putSetting('banner', req.validated.body);
  emitToAll('settings:banner', { banner: saved });
  return ok(res, saved, 'Banner updated');
});

const putAppInfo = asyncHandler(async (req, res) => {
  const saved = await putSetting('appInfo', resolveAppInfo(req.validated.body));
  emitToAll('settings:appInfo', { appInfo: saved });
  return ok(res, saved, 'App info updated');
});

// ─── NEW: Store status (public) ───────────────────────────────────────────────

/**
 * GET /api/store/status
 * Returns store open/closed state, delivery radius, center, min order, delivery fee.
 * Public — no auth required.
 */
const getStoreStatus = asyncHandler(async (req, res) => {
  const settings = await getStoreSettings();
  return ok(res, {
    isOpen: Boolean(settings.is_open),
    manualOpen: Boolean(settings.manual_open),
    withinHours: Boolean(settings.within_hours),
    storeOpenTime: settings.store_open_time ?? null,
    storeCloseTime: settings.store_close_time ?? null,
    closedReason: settings.closed_reason ?? null,
    closedMessage: settings.closed_message ?? null,
    nextOpenDisplay: settings.next_open_display ?? null,
    deliveryRadiusKm: Number(settings.delivery_radius_km || DEFAULT_STORE_SETTINGS.delivery_radius_km),
    centerLat: Number(settings.center_lat || 0),
    centerLng: Number(settings.center_lng || 0),
    minOrderAmount: Number(settings.min_order_amount || DEFAULT_STORE_SETTINGS.min_order_amount),
    deliveryFee: Number(settings.delivery_fee || DEFAULT_STORE_SETTINGS.delivery_fee),
  }, 'Store status');
});

// ─── NEW: Delivery zone check (public) ───────────────────────────────────────

/**
 * POST /api/store/check-delivery
 * Body: { lat: number, lng: number }
 * Returns: { deliverable: boolean, distanceKm: number }
 * Error: OUTSIDE_DELIVERY_ZONE (400) if not deliverable
 * Public — no auth required.
 */
const checkDelivery = asyncHandler(async (req, res) => {
  const { lat, lng } = req.body;

  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return fail(res, 400, 'lat and lng are required numbers');
  }

  const settings = await getStoreSettings();
  const radiusKm = Number(settings.delivery_radius_km || DEFAULT_STORE_SETTINGS.delivery_radius_km);
  const centerLat = Number(settings.center_lat || 0);
  const centerLng = Number(settings.center_lng || 0);

  // If store center is not configured yet, warn but allow (0,0 would block everyone)
  if (centerLat === 0 && centerLng === 0) {
    logger.warn('delivery_zone_center_not_configured', {});
    // Allow delivery when zone is not configured (fail open for dev)
    return ok(res, { deliverable: true, distanceKm: 0 }, 'Delivery available (zone not configured)');
  }

  const { deliverable, distanceKm } = isWithinDeliveryZone(centerLat, centerLng, lat, lng, radiusKm);

  if (!deliverable) {
    return fail(res, 400, 'Not available in your area — expanding soon!', {
      code: 'OUTSIDE_DELIVERY_ZONE',
      distanceKm,
      radiusKm,
    });
  }

  return ok(res, { deliverable: true, distanceKm }, 'Delivery available');
});

/**
 * POST /api/store/estimate-delivery
 * Body: { lat: number, lng: number, items?: [{ quantity: number }] }
 * Returns express ETA preview for checkout.
 */
const estimateDelivery = asyncHandler(async (req, res) => {
  const { lat, lng, items: rawItems } = req.body;

  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return fail(res, 400, 'lat and lng are required numbers');
  }

  const settings = await getStoreSettings();
  if (!Boolean(settings.is_open)) {
    return fail(
      res,
      400,
      settings.closed_message || 'Store is closed — orders resume when we open',
      {
        code: 'STORE_CLOSED',
        closedReason: settings.closed_reason ?? null,
        closedMessage: settings.closed_message ?? null,
      }
    );
  }

  const radiusKm = Number(settings.delivery_radius_km || DEFAULT_STORE_SETTINGS.delivery_radius_km);
  const centerLat = Number(settings.center_lat || DEFAULT_STORE_SETTINGS.center_lat);
  const centerLng = Number(settings.center_lng || DEFAULT_STORE_SETTINGS.center_lng);

  let distanceKm = 0;
  if (centerLat !== 0 || centerLng !== 0) {
    const zone = isWithinDeliveryZone(centerLat, centerLng, lat, lng, radiusKm);
    if (!zone.deliverable) {
      return fail(res, 400, 'Not available in your area — expanding soon!', {
        code: 'OUTSIDE_DELIVERY_ZONE',
        distanceKm: zone.distanceKm,
        radiusKm,
      });
    }
    distanceKm = zone.distanceKm;
  } else {
    distanceKm = haversineKm(centerLat, centerLng, lat, lng);
  }

  const items = Array.isArray(rawItems)
    ? rawItems
        .map((item) => ({ quantity: Math.max(1, Number(item?.quantity) || 1) }))
        .filter((item) => item.quantity > 0)
    : [];

  let queueDepth = 0;
  try {
    const { rows } = await query(
      `SELECT COUNT(*)::int AS count
       FROM orders
       WHERE status IN ('CONFIRMED', 'PACKING_STARTED', 'PACKED')`
    );
    queueDepth = Number(rows[0]?.count || 0);
  } catch (err) {
    logger.warn('estimate_delivery_queue_failed', { message: err?.message });
  }

  const etaResult = calculateExpressETA({
    placedAt: new Date(),
    items,
    queueDepth,
    distanceKm,
  });

  return ok(
    res,
    {
      etaMinutes: etaResult.etaMinutes,
      etaDisplay: etaResult.etaDisplay,
      estimatedTime: etaResult.etaTime.toISOString(),
      distanceKm: etaResult.breakdown.distanceKm,
      breakdown: etaResult.breakdown,
    },
    'Delivery estimate'
  );
});

// ─── NEW: Admin — update delivery zone ───────────────────────────────────────

/**
 * PUT /api/admin/store/delivery-zone
 * Body: { radiusKm: number, centerLat: number, centerLng: number }
 * Auth: Admin JWT required (enforced at route level)
 * Immediately updates zone — customer app respects next check-delivery call.
 */
const updateDeliveryZone = asyncHandler(async (req, res) => {
  const { radiusKm, centerLat, centerLng } = req.body;

  if (typeof radiusKm !== 'number' || radiusKm < 0.5 || radiusKm > 100) {
    return fail(res, 400, 'radiusKm must be a number between 0.5 and 100');
  }
  if (typeof centerLat !== 'number' || typeof centerLng !== 'number') {
    return fail(res, 400, 'centerLat and centerLng are required numbers');
  }

  try {
    // Upsert into store_settings
    await query(
      `INSERT INTO store_settings (delivery_radius_km, center_lat, center_lng, updated_at)
       VALUES ($1, $2, $3, NOW())
       ON CONFLICT DO UPDATE
         SET delivery_radius_km = EXCLUDED.delivery_radius_km,
             center_lat = EXCLUDED.center_lat,
             center_lng = EXCLUDED.center_lng,
             updated_at = NOW()`,
      [radiusKm, centerLat, centerLng]
    );
  } catch (err) {
    // ON CONFLICT DO UPDATE requires a unique/primary constraint — try a simpler approach
    if (err?.code === '42601' || err?.code === '42P01') {
      // Table may not exist — create minimal version and insert
      await query(
        `CREATE TABLE IF NOT EXISTS store_settings (
          id SERIAL PRIMARY KEY,
          delivery_radius_km DECIMAL(5,2) DEFAULT 5.0,
          center_lat DECIMAL(10,7) DEFAULT 0,
          center_lng DECIMAL(10,7) DEFAULT 0,
          min_order_amount DECIMAL(10,2) DEFAULT 150.0,
          delivery_fee DECIMAL(10,2) DEFAULT 30.0,
          is_open BOOLEAN DEFAULT true,
          updated_at TIMESTAMPTZ DEFAULT NOW()
        )`
      );
      // Delete and re-insert (single-row settings table)
      await query('DELETE FROM store_settings');
      await query(
        `INSERT INTO store_settings (delivery_radius_km, center_lat, center_lng)
         VALUES ($1, $2, $3)`,
        [radiusKm, centerLat, centerLng]
      );
    } else {
      throw err;
    }
  }

  // Broadcast to all connected clients so customer app can re-check zone
  emitToAll('store:delivery_zone_updated', { radiusKm, centerLat, centerLng });

  logger.info('delivery_zone_updated', { radiusKm, centerLat, centerLng, adminId: req.user?.id });

  return ok(res, { radiusKm, centerLat, centerLng }, 'Delivery zone updated');
});

// ─── NEW: Admin — toggle store open/close ─────────────────────────────────────

/**
 * PATCH /api/admin/store/toggle
 * No body needed — just toggles the is_open flag.
 * Auth: Admin JWT required.
 */
const toggleStoreOpen = asyncHandler(async (req, res) => {
  const { toggleManualStoreOpen } = require('../../utils/storeSettings.util');
  const settings = await toggleManualStoreOpen();

  emitToAll('store:status_changed', {
    isOpen: settings.is_open,
    manualOpen: settings.manual_open,
    closedMessage: settings.closed_message,
  });
  logger.info('store_toggle', {
    manualOpen: settings.manual_open,
    isOpen: settings.is_open,
    adminId: req.user?.id,
  });

  return ok(
    res,
    {
      isOpen: settings.is_open,
      manualOpen: settings.manual_open,
      closedMessage: settings.closed_message,
    },
    settings.manual_open
      ? 'Store manual switch is ON — orders allowed during open hours'
      : 'Store manual switch is OFF — orders paused until reopened'
  );
});

module.exports = {
  getTheme,
  getBanner,
  getAppInfo,
  putTheme,
  putBanner,
  putAppInfo,
  DEFAULT_THEME,
  DEFAULT_BANNER,
  DEFAULT_APP_INFO,
  // New store endpoints
  getStoreStatus,
  checkDelivery,
  estimateDelivery,
  updateDeliveryZone,
  toggleStoreOpen,
  // Helpers
  getStoreSettings,
};
