const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');
const { emitToAll } = require('../../socket/socket');
const { isWithinDeliveryZone } = require('../../utils/distance.util');

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

/** Default store settings used when DB row doesn't exist yet */
const DEFAULT_STORE_SETTINGS = {
  delivery_radius_km: 5.0,
  center_lat: 0,
  center_lng: 0,
  min_order_amount: 150.0,
  delivery_fee: 30.0,
  is_open: true,
};

// ─── Generic key-value settings helpers ──────────────────────────────────────

const getSetting = async (key) => {
  try {
    const { rows } = await query('SELECT value FROM app_settings WHERE key = $1', [key]);
    return rows[0]?.value || null;
  } catch (err) {
    if (err?.code === '42P01') return null;
    throw err;
  }
};

const putSetting = async (key, value) => {
  try {
    const { rows } = await query(
      `INSERT INTO app_settings (key, value, updated_at)
       VALUES ($1,$2,NOW())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
       RETURNING value`,
      [key, value]
    );
    return rows[0]?.value || value;
  } catch (err) {
    if (err?.code !== '42P01') throw err;

    try {
      await query(
        `CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value JSONB NOT NULL,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )`
      );
      const { rows } = await query(
        `INSERT INTO app_settings (key, value, updated_at)
         VALUES ($1,$2,NOW())
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
         RETURNING value`,
        [key, value]
      );
      return rows[0]?.value || value;
    } catch (e2) {
      logger.warn('settings_table_create_failed', { message: e2?.message, code: e2?.code });
      return value;
    }
  }
};

// ─── Store settings helpers (store_settings table) ────────────────────────────

/**
 * Reads the single store_settings row. Falls back to DEFAULT_STORE_SETTINGS if missing.
 */
const getStoreSettings = async () => {
  try {
    const { rows } = await query(
      `SELECT delivery_radius_km, center_lat, center_lng,
              min_order_amount, delivery_fee, is_open
       FROM store_settings
       LIMIT 1`
    );
    if (rows[0]) return rows[0];
    return DEFAULT_STORE_SETTINGS;
  } catch (err) {
    // Table may not exist yet
    if (err?.code === '42P01') return DEFAULT_STORE_SETTINGS;
    throw err;
  }
};

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
    return res.status(400).json({
      success: false,
      error: {
        code: 'OUTSIDE_DELIVERY_ZONE',
        message: 'Not available in your area — expanding soon!',
        data: { distanceKm, radiusKm },
      },
    });
  }

  return ok(res, { deliverable: true, distanceKm }, 'Delivery available');
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
  let newState;
  try {
    const { rows } = await query(
      `UPDATE store_settings SET is_open = NOT is_open, updated_at = NOW()
       RETURNING is_open`
    );
    if (!rows[0]) {
      // No row exists — create default as OPEN=false (closing)
      await query(
        `INSERT INTO store_settings (is_open) VALUES (false)
         ON CONFLICT DO NOTHING`
      );
      newState = false;
    } else {
      newState = Boolean(rows[0].is_open);
    }
  } catch (err) {
    if (err?.code === '42P01') {
      // Table missing — create and insert
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
      await query(`INSERT INTO store_settings DEFAULT VALUES`);
      newState = true;
    } else {
      throw err;
    }
  }

  emitToAll('store:status_changed', { isOpen: newState });
  logger.info('store_toggle', { isOpen: newState, adminId: req.user?.id });

  return ok(res, { isOpen: newState }, `Store is now ${newState ? 'OPEN' : 'CLOSED'}`);
});

module.exports = {
  getTheme,
  getBanner,
  putTheme,
  putBanner,
  DEFAULT_THEME,
  DEFAULT_BANNER,
  // New store endpoints
  getStoreStatus,
  checkDelivery,
  updateDeliveryZone,
  toggleStoreOpen,
};
