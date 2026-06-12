-- Meatvo (Blinkit-like) PostgreSQL schema
-- Run this file against your database (psql) before starting the API.

BEGIN;

-- Enums
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('admin', 'customer', 'delivery');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'PLACED',
    'CONFIRMED',
    'PACKED',
    'OUT_FOR_DELIVERY',
    'PICKED_UP',
    'ON_THE_WAY',
    'DELIVERED',
    'CANCELLED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_mode AS ENUM ('COD', 'ONLINE');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE assignment_status AS ENUM ('ASSIGNED', 'ACCEPTED', 'PICKED', 'DELIVERED', 'CANCELLED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE discount_type AS ENUM ('PERCENT', 'FLAT');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Tables
CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  role user_role NOT NULL DEFAULT 'customer',
  refresh_token_hash TEXT,
  mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  mfa_secret TEXT,
  mfa_backup_codes JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  image_url TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Case-insensitive-ish uniqueness for names
CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_name_lower ON categories (LOWER(name));
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(active);
CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON categories(sort_order);

CREATE TABLE IF NOT EXISTS products (
  id BIGSERIAL PRIMARY KEY,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  mrp NUMERIC(10,2) CHECK (mrp IS NULL OR mrp >= 0),
  image_url TEXT,
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  unit TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(active);

CREATE TABLE IF NOT EXISTS coupons (
  id BIGSERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  discount_type discount_type NOT NULL,
  discount_value NUMERIC(10,2) NOT NULL CHECK (discount_value >= 0),
  min_order_value NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (min_order_value >= 0),
  max_uses INTEGER CHECK (max_uses IS NULL OR max_uses >= 0),
  used_count INTEGER NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(active);

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status order_status NOT NULL DEFAULT 'PLACED',
  total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
  coupon_id BIGINT REFERENCES coupons(id) ON DELETE SET NULL,
  address JSONB NOT NULL,
  payment_mode payment_mode NOT NULL DEFAULT 'COD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  price NUMERIC(10,2) NOT NULL CHECK (price >= 0)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

CREATE TABLE IF NOT EXISTS delivery_partners (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  approved BOOLEAN NOT NULL DEFAULT TRUE,
  current_lat NUMERIC(10,7),
  current_lng NUMERIC(10,7),
  vehicle_type TEXT,
  vehicle_number TEXT,
  licence_number TEXT,
  bank_details TEXT,
  earnings NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (earnings >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_partners_online ON delivery_partners(is_online);
CREATE INDEX IF NOT EXISTS idx_delivery_partners_approved ON delivery_partners(approved);

-- Settings (theme/banner/etc)
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS value JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Backward-compatible column additions (safe for existing DBs)
DO $$ BEGIN
  ALTER TABLE categories ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT TRUE;
  ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
  ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS licence_number TEXT;
  ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS bank_details TEXT;
  ALTER TABLE delivery_partners ADD COLUMN IF NOT EXISTS earnings NUMERIC(10,2) NOT NULL DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS order_assignments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  delivery_partner_id BIGINT NOT NULL REFERENCES delivery_partners(id) ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status assignment_status NOT NULL DEFAULT 'ASSIGNED',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_assignments_partner ON order_assignments(delivery_partner_id);

CREATE TABLE IF NOT EXISTS banners (
  id BIGSERIAL PRIMARY KEY,
  image_url TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_banners_active ON banners(active);
CREATE INDEX IF NOT EXISTS idx_banners_sort_order ON banners(sort_order);

CREATE TABLE IF NOT EXISTS otp_logs (
  id BIGSERIAL PRIMARY KEY,
  phone TEXT NOT NULL,
  otp TEXT NOT NULL,
  template_id TEXT,
  msg91_response JSONB,
  expires_at TIMESTAMPTZ NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_logs_phone_created_at ON otp_logs(phone, created_at DESC);

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
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_slots_slot_date_name ON delivery_slots(slot_date, name);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_slot_date ON delivery_slots(slot_date);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_active_date ON delivery_slots(is_active, slot_date);

CREATE OR REPLACE FUNCTION auto_generate_delivery_slots()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  d DATE;
  horizon DATE := CURRENT_DATE + INTERVAL '13 days';
BEGIN
  d := CURRENT_DATE;
  WHILE d <= horizon LOOP
    INSERT INTO delivery_slots (name, start_time, end_time, slot_date, capacity, booked, is_active)
    VALUES
      ('Morning', '07:00:00', '11:00:00', d, 20, 0, true),
      ('Evening', '16:00:00', '20:00:00', d, 20, 0, true)
    ON CONFLICT (slot_date, name) DO NOTHING;
    d := d + 1;
  END LOOP;
END;
$$;

COMMIT;
