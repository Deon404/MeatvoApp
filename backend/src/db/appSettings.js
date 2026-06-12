const { query } = require('./postgres');

/** Add columns expected by the Node API when an older app_settings table already exists. */
const repairAppSettingsSchema = async () => {
  await query(
    `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS value JSONB NOT NULL DEFAULT '{}'::jsonb`
  );
  await query(
    `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  );
};

module.exports = { repairAppSettingsSchema };
