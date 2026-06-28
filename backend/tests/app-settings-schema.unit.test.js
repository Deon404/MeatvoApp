const fs = require('fs');
const path = require('path');

describe('app_settings canonical schema', () => {
  const readSource = (relativePath) =>
    fs.readFileSync(path.join(__dirname, '..', relativePath), 'utf8');

  test('ensureSchema uses id PK with operational columns (not key PK)', () => {
    const source = readSource('src/db/ensureSchema.js');
    expect(source).toContain('id SERIAL PRIMARY KEY');
    expect(source).toContain('store_acceptance_mode VARCHAR(32)');
    expect(source).not.toMatch(
      /CREATE TABLE IF NOT EXISTS app_settings[\s\S]*?key TEXT PRIMARY KEY/
    );
  });

  test('settings and admin controllers align on column-based schema', () => {
    const settingsSource = readSource('src/modules/settings/settings.controller.js');
    const adminSource = readSource('src/modules/admin/admin.controller.js');
    const storeSource = readSource('src/utils/storeSettings.util.js');

    expect(settingsSource).toContain('store_acceptance_mode VARCHAR(32)');
    expect(adminSource).not.toContain("key, value, delivery_charge");
    expect(storeSource).not.toContain("WHERE key = 'free_delivery_above'");
  });

  test('repairAppSettingsSchema covers all canonical columns', () => {
    const source = readSource('src/db/appSettings.js');
    const expected = [
      'value',
      'updated_at',
      'delivery_charge',
      'min_order_amount',
      'store_open',
      'store_acceptance_mode',
      'store_open_time',
      'store_close_time',
      'delivery_radius_km',
    ];
    for (const column of expected) {
      expect(source).toContain(`'${column}'`);
    }
  });

  test('ensureSchema does not backfill weight reconciliation on startup', () => {
    const source = readSource('src/db/ensureSchema.js');
    expect(source).not.toContain('orders.backfill_weight_reconciliation_completed');
    expect(source).not.toContain("SET weight_reconciliation_status = 'COMPLETED'");
  });

  test('ensureSchema payment_status CHECK includes COLLECTED', () => {
    const source = readSource('src/db/ensureSchema.js');
    expect(source).toContain('orders_payment_status_collected_check');
    expect(source).toContain("'COLLECTED'");
  });
});
