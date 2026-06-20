const { query } = require('./postgres');

const REQUIRED_APP_SETTINGS_COLUMNS = [
  'value',
  'updated_at',
  'delivery_charge',
  'min_order_amount',
  'store_open',
  'store_open_time',
  'store_close_time',
  'delivery_radius_km',
];

const COLUMN_ALTER_STATEMENTS = {
  value: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS value JSONB NOT NULL DEFAULT '{}'::jsonb`,
  updated_at: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
  delivery_charge: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_charge NUMERIC(10,2) DEFAULT 30`,
  min_order_amount: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS min_order_amount NUMERIC(10,2) DEFAULT 150`,
  store_open: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS store_open BOOLEAN DEFAULT true`,
  store_open_time: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS store_open_time TIME`,
  store_close_time: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS store_close_time TIME`,
  delivery_radius_km: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS delivery_radius_km NUMERIC(5,2) DEFAULT 8.0`,
};

/** Add columns expected by the Node API when an older app_settings table already exists. */
const repairAppSettingsSchema = async () => {
  const { rows } = await query(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'app_settings'`
  );

  const existing = new Set(rows.map((row) => row.column_name));
  const missing = REQUIRED_APP_SETTINGS_COLUMNS.filter((col) => !existing.has(col));

  if (missing.length === 0) {
    return;
  }

  for (const column of missing) {
    await query(COLUMN_ALTER_STATEMENTS[column]);
  }
};

module.exports = { repairAppSettingsSchema };
