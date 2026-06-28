const { query } = require('./postgres');
const { logger } = require('../utils/logger');
const { repairAppSettingsSchema } = require('./appSettings');
const { SCHEMA_DEFAULTS } = require('../config/businessRules');

const ensureSchema = async () => {
  const steps = [
    {
      name: 'app_settings',
      sql: `
        CREATE TABLE IF NOT EXISTS app_settings (
          id SERIAL PRIMARY KEY,
          delivery_charge NUMERIC(10,2) DEFAULT ${SCHEMA_DEFAULTS.deliveryFee},
          min_order_amount NUMERIC(10,2) DEFAULT ${SCHEMA_DEFAULTS.minOrderAmount},
          store_open BOOLEAN DEFAULT true,
          store_acceptance_mode VARCHAR(32) DEFAULT 'accepting',
          store_open_time TIME,
          store_close_time TIME,
          delivery_radius_km NUMERIC(5,2) DEFAULT ${SCHEMA_DEFAULTS.deliveryRadiusKm},
          value JSONB NOT NULL DEFAULT '{}'::jsonb,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'app_settings.columns',
      run: repairAppSettingsSchema,
    },
    {
      name: 'app_settings.id',
      sql: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS id SERIAL`,
    },
    {
      name: 'store_settings',
      sql: `
        CREATE TABLE IF NOT EXISTS store_settings (
          id SERIAL PRIMARY KEY,
          delivery_radius_km DECIMAL(5,2) DEFAULT ${SCHEMA_DEFAULTS.deliveryRadiusKm},
          center_lat DECIMAL(10,7) DEFAULT 0,
          center_lng DECIMAL(10,7) DEFAULT 0,
          min_order_amount DECIMAL(10,2) DEFAULT ${SCHEMA_DEFAULTS.minOrderAmount},
          delivery_fee DECIMAL(10,2) DEFAULT ${SCHEMA_DEFAULTS.deliveryFee},
          is_open BOOLEAN DEFAULT true,
          updated_at TIMESTAMPTZ DEFAULT NOW()
        )
      `,
    },
    {
      name: 'store_settings.id',
      sql: `ALTER TABLE store_settings ADD COLUMN IF NOT EXISTS id SERIAL`,
    },
    {
      name: 'store_settings.seed_defaults',
      sql: `
        INSERT INTO store_settings (delivery_radius_km, center_lat, center_lng, min_order_amount, delivery_fee, is_open)
        SELECT ${SCHEMA_DEFAULTS.deliveryRadiusKm}, ${SCHEMA_DEFAULTS.centerLat}, ${SCHEMA_DEFAULTS.centerLng}, ${SCHEMA_DEFAULTS.minOrderAmount}, ${SCHEMA_DEFAULTS.deliveryFee}, true
        WHERE NOT EXISTS (SELECT 1 FROM store_settings)
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
      name: 'products.mrp',
      sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS mrp NUMERIC(10,2)`,
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
      name: 'users.is_active',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true`,
    },
    {
      name: 'delivery_partners.cleanup_non_delivery_roles',
      sql: `
        DELETE FROM delivery_partners dp
        USING users u
        WHERE dp.user_id = u.id
          AND u.role <> 'delivery'
          AND NOT EXISTS (
            SELECT 1 FROM order_assignments oa
            WHERE oa.delivery_partner_id = dp.id
          )
      `,
    },
    {
      name: 'order_assignments_table',
      sql: `
        CREATE TABLE IF NOT EXISTS order_assignments (
          id BIGSERIAL PRIMARY KEY,
          order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
          delivery_partner_id BIGINT NOT NULL REFERENCES delivery_partners(id) ON DELETE RESTRICT,
          assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          status VARCHAR(20) NOT NULL DEFAULT 'ASSIGNED'
        )
      `,
    },
    {
      name: 'order_assignments_partner_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_order_assignments_partner ON order_assignments(delivery_partner_id)`,
    },
    {
      name: 'users.mfa_enabled',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE`,
    },
    {
      name: 'users.mfa_secret',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_secret TEXT`,
    },
    {
      name: 'users.mfa_backup_codes',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_backup_codes JSONB`,
    },
    {
      name: 'payment_transactions_table',
      sql: `
        CREATE TABLE IF NOT EXISTS payment_transactions (
          id BIGSERIAL PRIMARY KEY,
          order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
          amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
          status VARCHAR(50) NOT NULL DEFAULT 'INITIATED' CHECK (status IN ('INITIATED', 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED')),
          gateway VARCHAR(50) NOT NULL DEFAULT 'CASHFREE',
          gateway_order_id VARCHAR(100),
          gateway_payment_id VARCHAR(100),
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
      name: 'payment_transactions.gateway_order_id',
      sql: `ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS gateway_order_id VARCHAR(100)`,
    },
    {
      name: 'payment_transactions.gateway_payment_id',
      sql: `ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS gateway_payment_id VARCHAR(100)`,
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
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'COLLECTED'))`,
    },
    {
      name: 'orders_payment_status_collected_check',
      run: async () => {
        await query(`
          DO $$
          BEGIN
            IF EXISTS (
              SELECT 1 FROM pg_constraint
              WHERE conname = 'orders_payment_status_check'
            ) THEN
              ALTER TABLE orders DROP CONSTRAINT orders_payment_status_check;
            END IF;
          END $$;
        `);
        await query(`
          ALTER TABLE orders
          ADD CONSTRAINT orders_payment_status_check
          CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'COLLECTED'))
        `);
      },
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
          address_line1 TEXT NOT NULL,
          address_line2 TEXT,
          city VARCHAR(100) DEFAULT 'Dhanbad',
          state VARCHAR(100) DEFAULT 'Jharkhand',
          pincode VARCHAR(10),
          landmark TEXT,
          address_type VARCHAR(20) DEFAULT 'HOME',
          latitude DECIMAL(10,8) DEFAULT 23.7957,
          longitude DECIMAL(11,8) DEFAULT 86.4304,
          is_default BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          label TEXT DEFAULT 'home',
          address_line TEXT,
          lat NUMERIC(10,7),
          lng NUMERIC(10,7)
        )
      `,
    },
    {
      name: 'addresses_address_line1',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS address_line1 TEXT`,
    },
    {
      name: 'addresses_address_line2',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS address_line2 TEXT`,
    },
    {
      name: 'addresses_city',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS city VARCHAR(100) DEFAULT 'Dhanbad'`,
    },
    {
      name: 'addresses_state',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS state VARCHAR(100) DEFAULT 'Jharkhand'`,
    },
    {
      name: 'addresses_pincode',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS pincode VARCHAR(10) DEFAULT ''`,
    },
    {
      name: 'addresses_address_type',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS address_type VARCHAR(20) DEFAULT 'HOME'`,
    },
    {
      name: 'addresses_latitude',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS latitude DECIMAL(10,8) DEFAULT 23.7957`,
    },
    {
      name: 'addresses_longitude',
      sql: `ALTER TABLE addresses ADD COLUMN IF NOT EXISTS longitude DECIMAL(11,8) DEFAULT 86.4304`,
    },
    {
      name: 'addresses_column_defaults',
      sql: `
        ALTER TABLE addresses ALTER COLUMN city SET DEFAULT 'Dhanbad';
        ALTER TABLE addresses ALTER COLUMN state SET DEFAULT 'Jharkhand';
        ALTER TABLE addresses ALTER COLUMN latitude SET DEFAULT 23.7957;
        ALTER TABLE addresses ALTER COLUMN longitude SET DEFAULT 86.4304;
        ALTER TABLE addresses ALTER COLUMN address_type SET DEFAULT 'HOME'
      `,
    },
    {
      name: 'addresses_backfill_from_legacy',
      sql: `
        UPDATE addresses
        SET address_line1 = COALESCE(address_line1, address_line),
            latitude = COALESCE(latitude, lat),
            longitude = COALESCE(longitude, lng),
            address_type = COALESCE(address_type, UPPER(COALESCE(label, 'home')))
        WHERE address_line1 IS NULL OR latitude IS NULL OR longitude IS NULL OR address_type IS NULL
      `,
    },
    {
      name: 'addresses_legacy_nullable',
      sql: `
        ALTER TABLE addresses ALTER COLUMN label SET DEFAULT 'home';
        ALTER TABLE addresses ALTER COLUMN address_line DROP NOT NULL;
        ALTER TABLE addresses ALTER COLUMN lat DROP NOT NULL;
        ALTER TABLE addresses ALTER COLUMN lng DROP NOT NULL
      `,
    },
    {
      name: 'addresses_indexes',
      sql: `
        CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
        CREATE INDEX IF NOT EXISTS idx_addresses_default ON addresses(user_id, is_default);
      `,
    },
    {
      name: 'otp_logs.template_id',
      sql: `ALTER TABLE otp_logs ADD COLUMN IF NOT EXISTS template_id TEXT`,
    },
    {
      name: 'otp_logs.msg91_response',
      sql: `ALTER TABLE otp_logs ADD COLUMN IF NOT EXISTS msg91_response JSONB`,
    },
    {
      name: 'categories.seed_defaults',
      sql: `
        INSERT INTO categories (name, image_url, sort_order, active)
        SELECT v.name, v.image_url, v.sort_order, TRUE
        FROM (
          VALUES
            ('Chicken', 'https://images.unsplash.com/photo-1604503468506-a8da286d644f?auto=format&fit=crop&w=600&q=80', 1),
            ('Mutton', 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=600&q=80', 2),
            ('Fish', 'https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&w=600&q=80', 3),
            ('Eggs', 'https://images.unsplash.com/photo-1582729478250-c89cae4dc85b?auto=format&fit=crop&w=600&q=80', 4)
        ) AS v(name, image_url, sort_order)
        WHERE NOT EXISTS (
          SELECT 1 FROM categories c WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(v.name))
        )
      `,
    },
    {
      name: 'categories.backfill_images',
      sql: `
        UPDATE categories SET image_url = CASE
          WHEN LOWER(name) LIKE '%chicken%' THEN 'https://images.unsplash.com/photo-1604503468506-a8da286d644f?auto=format&fit=crop&w=600&q=80'
          WHEN LOWER(name) LIKE '%mutton%'
            OR LOWER(name) LIKE '%lamb%'
            OR LOWER(name) LIKE '%goat%' THEN 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=600&q=80'
          WHEN LOWER(name) LIKE '%fish%'
            OR LOWER(name) LIKE '%seafood%' THEN 'https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&w=600&q=80'
          WHEN LOWER(name) LIKE '%egg%' THEN 'https://images.unsplash.com/photo-1582729478250-c89cae4dc85b?auto=format&fit=crop&w=600&q=80'
          ELSE image_url
        END
        WHERE image_url IS NULL OR TRIM(image_url) = ''
      `,
    },
    {
      name: 'delivery_slots.drop_legacy_shape',
      sql: `
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'delivery_slots'
              AND column_name = 'slot_time'
          ) AND NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'delivery_slots'
              AND column_name = 'slot_date'
          ) THEN
            DROP TABLE IF EXISTS delivery_slots CASCADE;
          END IF;
        END $$
      `,
    },
    {
      name: 'delivery_slots_table',
      sql: `
        CREATE TABLE IF NOT EXISTS delivery_slots (
          id BIGSERIAL PRIMARY KEY,
          name VARCHAR(50) NOT NULL,
          start_time TIME NOT NULL,
          end_time TIME NOT NULL,
          slot_date DATE NOT NULL,
          capacity INT NOT NULL DEFAULT 20,
          booked INT NOT NULL DEFAULT 0,
          is_active BOOLEAN NOT NULL DEFAULT true,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'delivery_slots_indexes',
      sql: `
        CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_slots_slot_date_name ON delivery_slots(slot_date, name);
        CREATE INDEX IF NOT EXISTS idx_delivery_slots_slot_date ON delivery_slots(slot_date);
        CREATE INDEX IF NOT EXISTS idx_delivery_slots_active_date ON delivery_slots(is_active, slot_date);
      `,
    },
    {
      name: 'delivery_slots.auto_generate_function',
      sql: `
        CREATE OR REPLACE FUNCTION auto_generate_delivery_slots()
        RETURNS void
        LANGUAGE plpgsql
        AS $$
        BEGIN
          -- Delivery slots are admin-managed (today + 2 days). No automatic seeding.
          RETURN;
        END;
        $$
      `,
    },
    {
      name: 'delivery_slots.auto_generate_admin_managed_v2',
      sql: `
        CREATE OR REPLACE FUNCTION auto_generate_delivery_slots()
        RETURNS void
        LANGUAGE plpgsql
        AS $$
        BEGIN
          RETURN;
        END;
        $$
      `,
    },
    {
      name: 'delivery_slots.seed',
      sql: `SELECT auto_generate_delivery_slots()`,
    },
    {
      name: 'order_status.picked_up',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PICKED_UP'`,
    },
    {
      name: 'order_status.on_the_way',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'ON_THE_WAY'`,
    },
    {
      name: 'delivery_slots.max_orders',
      sql: `ALTER TABLE delivery_slots ADD COLUMN IF NOT EXISTS max_orders INTEGER DEFAULT 15`,
    },
    {
      name: 'delivery_slots.current_orders',
      sql: `ALTER TABLE delivery_slots ADD COLUMN IF NOT EXISTS current_orders INTEGER DEFAULT 0`,
    },
    {
      name: 'delivery_slots.backfill_current_orders',
      sql: `UPDATE delivery_slots SET current_orders = COALESCE(booked, 0) WHERE current_orders = 0`,
    },
    {
      name: 'orders.estimated_delivery_time',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS estimated_delivery_time TIMESTAMPTZ`,
    },
    {
      name: 'orders.eta_minutes',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS eta_minutes INTEGER`,
    },
    {
      name: 'orders.delivery_slot_id',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_slot_id BIGINT`,
    },
    {
      name: 'orders.delivery_slot_id_nullable',
      sql: `ALTER TABLE orders ALTER COLUMN delivery_slot_id DROP NOT NULL`,
    },
    {
      name: 'orders.eta_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_orders_estimated_delivery_time ON orders(estimated_delivery_time)`,
    },
    {
      name: 'orders.updated_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    },
    {
      name: 'delivery_partners.updated_at',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    },
    {
      name: 'order_assignments.updated_at',
      sql: `ALTER TABLE order_assignments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    },
    {
      name: 'users.fcm_token',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT`,
    },
    {
      name: 'users.fcm_token_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL`,
    },
    {
      name: 'schema_migrations_table',
      sql: `
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL UNIQUE,
          applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'order_status.payment_pending',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PAYMENT_PENDING'`,
    },
    {
      name: 'order_status.payment_verified',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PAYMENT_VERIFIED'`,
    },
    {
      name: 'order_status.packing_started',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PACKING_STARTED'`,
    },
    {
      name: 'order_status.rider_assigned',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_ASSIGNED'`,
    },
    {
      name: 'order_status.rider_accepted',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_ACCEPTED'`,
    },
    {
      name: 'order_status.rider_rejected',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_REJECTED'`,
    },
    {
      name: 'order_status.rider_nearby',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_NEARBY'`,
    },
    {
      name: 'order_status.refunded',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'REFUNDED'`,
    },
    {
      name: 'order_status.failed_delivery',
      sql: `ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'FAILED_DELIVERY'`,
    },
    {
      name: 'assignment_status.failed',
      sql: `ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'FAILED'`,
    },
    {
      name: 'orders.failed_delivery_reason',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS failed_delivery_reason TEXT`,
    },
    {
      name: 'orders.failed_delivery_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS failed_delivery_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.failed_delivery_by',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS failed_delivery_by BIGINT REFERENCES users(id) ON DELETE SET NULL`,
    },
    {
      name: 'orders.returned_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS returned_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.returned_by',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS returned_by BIGINT REFERENCES users(id) ON DELETE SET NULL`,
    },
    {
      name: 'orders.return_reason',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS return_reason TEXT`,
    },
    {
      name: 'orders.return_condition',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS return_condition TEXT`,
    },
    {
      name: 'orders.failed_delivery_resolution',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS failed_delivery_resolution TEXT`,
    },
    {
      name: 'orders.failed_delivery_resolved_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS failed_delivery_resolved_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.failed_delivery_resolved_by',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS failed_delivery_resolved_by BIGINT REFERENCES users(id) ON DELETE SET NULL`,
    },
    {
      name: 'admin_tasks_table',
      sql: `
        CREATE TABLE IF NOT EXISTS admin_tasks (
          id BIGSERIAL PRIMARY KEY,
          task_type VARCHAR(50) NOT NULL,
          order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
          status VARCHAR(20) NOT NULL DEFAULT 'open',
          payload JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          resolved_at TIMESTAMPTZ,
          resolved_by BIGINT REFERENCES users(id) ON DELETE SET NULL
        )
      `,
    },
    {
      name: 'admin_tasks_open_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_admin_tasks_open ON admin_tasks(status, task_type) WHERE status = 'open'`,
    },
    {
      name: 'order_assignments.delivery_image_url',
      sql: `ALTER TABLE order_assignments ADD COLUMN IF NOT EXISTS delivery_image_url TEXT`,
    },
    {
      name: 'order_assignments.delivery_notes',
      sql: `ALTER TABLE order_assignments ADD COLUMN IF NOT EXISTS delivery_notes TEXT`,
    },
    {
      name: 'order_assignments.delivered_at',
      sql: `ALTER TABLE order_assignments ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ`,
    },
    {
      name: 'order_assignments.batch_ids',
      sql: `ALTER TABLE order_assignments ADD COLUMN IF NOT EXISTS batch_ids JSONB NOT NULL DEFAULT '[]'::jsonb`,
    },
    {
      name: 'users.email',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT`,
    },
    {
      name: 'users.profile_image_url',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_url TEXT`,
    },
    {
      name: 'users.updated_at',
      sql: `ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    },
    {
      name: 'user_notifications_table',
      sql: `
        CREATE TABLE IF NOT EXISTS user_notifications (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          type VARCHAR(50) NOT NULL DEFAULT 'custom',
          title VARCHAR(255) NOT NULL,
          body TEXT NOT NULL,
          data JSONB NOT NULL DEFAULT '{}'::jsonb,
          is_read BOOLEAN NOT NULL DEFAULT FALSE,
          read_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'user_notifications.user_id_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id, created_at DESC)`,
    },
    {
      name: 'wishlists_table',
      sql: `
        CREATE TABLE IF NOT EXISTS wishlists (
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          PRIMARY KEY (user_id, product_id)
        )
      `,
    },
    {
      name: 'order_reviews_table',
      sql: `
        CREATE TABLE IF NOT EXISTS order_reviews (
          id BIGSERIAL PRIMARY KEY,
          order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          rider_rating SMALLINT,
          product_quality_rating SMALLINT,
          delivery_speed_rating SMALLINT,
          feedback TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (order_id, user_id)
        )
      `,
    },
    {
      name: 'product_ratings_table',
      sql: `
        CREATE TABLE IF NOT EXISTS product_ratings (
          id BIGSERIAL PRIMARY KEY,
          product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
          rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
          review TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (product_id, user_id, order_id)
        )
      `,
    },
    {
      name: 'order_items.ordered_weight_g',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS ordered_weight_g INTEGER`,
    },
    {
      name: 'order_items.actual_weight_g',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS actual_weight_g INTEGER`,
    },
    {
      name: 'order_items.weight_delta_g',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS weight_delta_g INTEGER`,
    },
    {
      name: 'order_items.supplement_g',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS supplement_g INTEGER NOT NULL DEFAULT 0`,
    },
    {
      name: 'order_items.weight_refund_amount',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS weight_refund_amount NUMERIC(10,2) NOT NULL DEFAULT 0`,
    },
    {
      name: 'order_items.weight_reconciliation_action',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS weight_reconciliation_action VARCHAR(50)`,
    },
    {
      name: 'order_items.reconciled_at',
      sql: `ALTER TABLE order_items ADD COLUMN IF NOT EXISTS reconciled_at TIMESTAMPTZ`,
    },
    {
      name: 'order_items.backfill_ordered_weight_g',
      sql: `
        UPDATE order_items oi
        SET ordered_weight_g = COALESCE(
          oi.ordered_weight_g,
          GREATEST(1, oi.quantity) * COALESCE(
            (SELECT (p.weight_variants)[1] FROM products p WHERE p.id = oi.product_id),
            500
          )
        )
        WHERE oi.ordered_weight_g IS NULL
      `,
    },
    {
      name: 'orders.packed_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS packed_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.weight_reconciliation_status',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS weight_reconciliation_status VARCHAR(30) NOT NULL DEFAULT 'PENDING'`,
    },
    {
      name: 'orders.weight_reconciliation_completed_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS weight_reconciliation_completed_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.weight_reconciliation_total_refund',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS weight_reconciliation_total_refund NUMERIC(10,2) NOT NULL DEFAULT 0`,
    },
    {
      name: 'order_weight_reconciliations_table',
      sql: `
        CREATE TABLE IF NOT EXISTS order_weight_reconciliations (
          id BIGSERIAL PRIMARY KEY,
          order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
          order_item_id BIGINT NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
          ordered_weight_g INTEGER NOT NULL,
          actual_weight_g INTEGER NOT NULL,
          delta_g INTEGER NOT NULL,
          supplement_g INTEGER NOT NULL DEFAULT 0,
          refund_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
          reconciliation_action VARCHAR(50) NOT NULL,
          reconciled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          reconciled_by BIGINT REFERENCES users(id) ON DELETE SET NULL
        )
      `,
    },
    {
      name: 'order_weight_reconciliations.order_id_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_order_weight_reconciliations_order_id ON order_weight_reconciliations(order_id)`,
    },
    {
      name: 'order_partial_refunds_table',
      sql: `
        CREATE TABLE IF NOT EXISTS order_partial_refunds (
          id BIGSERIAL PRIMARY KEY,
          order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
          order_item_id BIGINT REFERENCES order_items(id) ON DELETE SET NULL,
          amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
          reason VARCHAR(100) NOT NULL DEFAULT 'weight_reconciliation',
          status VARCHAR(20) NOT NULL DEFAULT 'RECORDED',
          payment_mode VARCHAR(20),
          gateway_refund_id VARCHAR(100),
          idempotency_key VARCHAR(40),
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'order_partial_refunds.order_id_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_order_partial_refunds_order_id ON order_partial_refunds(order_id)`,
    },
    {
      name: 'order_partial_refunds.gateway_refund_id',
      sql: `ALTER TABLE order_partial_refunds ADD COLUMN IF NOT EXISTS gateway_refund_id VARCHAR(100)`,
    },
    {
      name: 'order_partial_refunds.idempotency_key',
      sql: `ALTER TABLE order_partial_refunds ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(40)`,
    },
    {
      name: 'order_partial_refunds.idempotency_key_unique',
      sql: `CREATE UNIQUE INDEX IF NOT EXISTS idx_order_partial_refunds_idempotency ON order_partial_refunds(idempotency_key) WHERE idempotency_key IS NOT NULL`,
    },
    {
      name: 'inventory_movements_table',
      sql: `
        CREATE TABLE IF NOT EXISTS inventory_movements (
          id BIGSERIAL PRIMARY KEY,
          product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
          order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
          order_item_id BIGINT REFERENCES order_items(id) ON DELETE SET NULL,
          movement_type VARCHAR(50) NOT NULL,
          quantity_grams INTEGER NOT NULL CHECK (quantity_grams >= 0),
          metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'inventory_movements.order_id_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_inventory_movements_order_id ON inventory_movements(order_id)`,
    },
    {
      name: 'operational_events_table',
      sql: `
        CREATE TABLE IF NOT EXISTS operational_events (
          id BIGSERIAL PRIMARY KEY,
          event_type VARCHAR(100) NOT NULL,
          order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
          actor_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
          payload JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'operational_events.type_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_operational_events_type ON operational_events(event_type, created_at DESC)`,
    },
    {
      name: 'delivery_partners.operational_status',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS operational_status VARCHAR(50) NOT NULL DEFAULT 'normal'`,
    },
    {
      name: 'operational_events.rider_id',
      sql: `ALTER TABLE operational_events ADD COLUMN IF NOT EXISTS rider_id BIGINT REFERENCES delivery_partners(id) ON DELETE SET NULL`,
    },
    {
      name: 'operational_events.order_id_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_operational_events_order_id ON operational_events(order_id, created_at DESC)`,
    },
    {
      name: 'operational_events.rider_id_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_operational_events_rider_id ON operational_events(rider_id, created_at DESC)`,
    },
    {
      name: 'orders.confirmed_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.packing_started_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS packing_started_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.dispatch_queued_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispatch_queued_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.assigned_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.rider_accepted_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS rider_accepted_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.out_for_delivery_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS out_for_delivery_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.delivered_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ`,
    },
    {
      name: 'orders.refunded_at',
      sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ`,
    },
    {
      name: 'delivery_batches_table',
      sql: `
        CREATE TABLE IF NOT EXISTS delivery_batches (
          id BIGSERIAL PRIMARY KEY,
          anchor_order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
          batch_size INT NOT NULL,
          order_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'delivery_batches.anchor_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_delivery_batches_anchor ON delivery_batches(anchor_order_id, created_at DESC)`,
    },
    {
      name: 'capacity_suggestions_table',
      sql: `
        CREATE TABLE IF NOT EXISTS capacity_suggestions (
          id BIGSERIAL PRIMARY KEY,
          suggested_mode VARCHAR(32) NOT NULL,
          current_mode VARCHAR(32) NOT NULL,
          reason TEXT NOT NULL,
          severity VARCHAR(16) NOT NULL,
          signals JSONB NOT NULL DEFAULT '{}'::jsonb,
          dismissed_until TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'capacity_suggestions.created_at_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_capacity_suggestions_created_at ON capacity_suggestions(created_at DESC)`,
    },
    {
      name: 'business_metrics_daily_rollup_table',
      sql: `
        CREATE TABLE IF NOT EXISTS business_metrics_daily_rollup (
          id BIGSERIAL PRIMARY KEY,
          metric_date DATE NOT NULL UNIQUE,
          metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
          data_completeness JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `,
    },
    {
      name: 'business_metrics_daily_rollup.metric_date_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_business_metrics_daily_rollup_date ON business_metrics_daily_rollup(metric_date DESC)`,
    },
    {
      name: 'delivery_partners.availability_status',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS availability_status VARCHAR(20) NOT NULL DEFAULT 'offline'`,
    },
    {
      name: 'delivery_partners.estimated_return_at',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS estimated_return_at TIMESTAMPTZ`,
    },
    {
      name: 'delivery_partners.estimated_return_minutes',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS estimated_return_minutes INT`,
    },
    {
      name: 'delivery_partners.active_order_count',
      sql: `ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS active_order_count INT NOT NULL DEFAULT 0`,
    },
    {
      name: 'delivery_partners.availability_status_index',
      sql: `CREATE INDEX IF NOT EXISTS idx_delivery_partners_availability ON delivery_partners(availability_status) WHERE is_online = TRUE`,
    },
  ];

  for (const step of steps) {
    try {
      if (step.run) {
        await step.run();
      } else {
        await query(step.sql);
      }
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

