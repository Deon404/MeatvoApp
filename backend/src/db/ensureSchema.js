const { query } = require('./postgres');
const { logger } = require('../utils/logger');

const ensureSchema = async () => {
  const steps = [
    {
      name: 'app_settings',
      sql: `
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value JSONB NOT NULL,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'categories.sort_order',
      sql: `ALTER TABLE categories ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0`,
    },
    {
      name: 'products.base_price_per_kg',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS base_price_per_kg NUMERIC(10,2)`,
    },
    {
      name: 'products.base_price_per_kg_backfill',
      sql: `UPDATE products SET base_price_per_kg = COALESCE(base_price_per_kg, price, 0)`,
    },
    {
      name: 'products.weight_variants',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS weight_variants INTEGER[] NOT NULL DEFAULT ARRAY[500]::INTEGER[]`,
    },
    {
      name: 'products.cut_types',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS cut_types TEXT[]`,
    },
    {
      name: 'products.marination_options',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS marination_options JSONB`,
    },
    {
      name: 'products.freshness_date',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS freshness_date DATE`,
    },
    {
      name: 'products.created_at',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    },
    {
      name: 'products.updated_at',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    },
    {
      name: 'delivery_partners.approved',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT TRUE`,
    },
    {
      name: 'delivery_partners.vehicle_number',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS vehicle_number TEXT`,
    },
    {
      name: 'delivery_partners.licence_number',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS licence_number TEXT`,
    },
    {
      name: 'delivery_partners.bank_details',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS bank_details TEXT`,
    },
    {
      name: 'delivery_partners.earnings',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS earnings NUMERIC(10,2) NOT NULL DEFAULT 0`,
    },
    {
      name: 'payment_transactions_table',
      sql: `
        CREATE TABLE IF NOT EXISTS payment_transactions (
          id BIGSERIAL PRIMARY KEY,
          order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
          amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
          status VARCHAR(50) NOT NULL DEFAULT 'INITIATED' CHECK (status IN ('INITIATED', 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED')),
          gateway VARCHAR(50) NOT NULL DEFAULT 'PHONEPE',
          gateway_transaction_id TEXT,
          payment_url TEXT,
          gateway_response JSONB,
          failure_reason TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'payment_transactions_indexes',
      sql: `
        CREATE INDEX IF NOT EXISTS idx_payment_transactions_order_id ON payment_transactions(order_id);
        CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
        CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_transaction_id ON payment_transactions(gateway_transaction_id);
        CREATE INDEX IF NOT EXISTS idx_payment_transactions_created_at ON payment_transactions(created_at);
      `,
    },
    {
      name: 'orders_payment_status',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED'))`,
    },
    {
      name: 'orders_payment_status_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status)`,
    },
    {
      name: 'addresses_table',
      sql: `
        CREATE TABLE IF NOT EXISTS addresses (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          label TEXT NOT NULL,
          address_line TEXT NOT NULL,
          landmark TEXT,
          lat NUMERIC(10,7) NOT NULL,
          lng NUMERIC(10,7) NOT NULL,
          is_default BOOLEAN NOT NULL DEFAULT FALSE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'addresses_indexes',
      sql: `
        CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
        CREATE INDEX IF NOT EXISTS idx_addresses_default ON addresses(user_id, is_default);
      `,
    },
  ];

  for (const step of steps) {
    try {
      await query(step.sql);
    } catch (err) {
      logger.warn('schema_ensure_failed', {
        step: step.name,
        message: err?.message,
        code: err?.code,
      });
    }
  }
};

module.exports = { ensureSchema };

