-- ============================================================================
-- MEATVO - COMPLETE POSTGRESQL DATABASE ARCHITECTURE
-- Production-Ready Schema with Audit, Partitioning, and Soft Deletes
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Trigram indexing for full-text search
CREATE EXTENSION IF NOT EXISTS "postgis";        -- Geospatial data (rider locations)
CREATE EXTENSION IF NOT EXISTS "btree_gin";      -- GIN indexes on scalar types

-- ============================================================================
-- SECTION 2: CUSTOM TYPES & ENUMS
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('admin', 'customer', 'delivery', 'support');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE user_status AS ENUM ('active', 'suspended', 'deleted');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'PENDING',
    'PLACED',
    'CONFIRMED',
    'PACKED',
    'OUT_FOR_DELIVERY',
    'PICKED_UP',
    'ON_THE_WAY',
    'DELIVERED',
    'CANCELLED',
    'REFUNDED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_mode AS ENUM ('COD', 'ONLINE', 'WALLET', 'MIXED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'PENDING',
    'INITIATED',
    'SUCCESS',
    'FAILED',
    'REFUNDED',
    'PARTIALLY_REFUNDED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_gateway AS ENUM ('PHONEPE', 'RAZORPAY', 'PAYTM', 'MANUAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE assignment_status AS ENUM (
    'ASSIGNED',
    'ACCEPTED',
    'PICKED',
    'DELIVERED',
    'CANCELLED',
    'REJECTED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE discount_type AS ENUM ('PERCENT', 'FLAT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE coupon_applicability AS ENUM ('ALL', 'FIRST_ORDER', 'CATEGORY_SPECIFIC', 'USER_SPECIFIC');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE notification_type AS ENUM (
    'ORDER',
    'PAYMENT',
    'DELIVERY',
    'PROMOTIONAL',
    'SYSTEM',
    'REFERRAL',
    'WALLET'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE notification_channel AS ENUM ('PUSH', 'SMS', 'EMAIL', 'IN_APP');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE wallet_transaction_type AS ENUM (
    'CREDIT',
    'DEBIT',
    'REFUND',
    'CASHBACK',
    'REFERRAL_BONUS',
    'WITHDRAWAL'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE referral_status AS ENUM ('PENDING', 'COMPLETED', 'EXPIRED', 'CLAIMED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE rider_availability AS ENUM ('AVAILABLE', 'BUSY', 'OFFLINE', 'BREAK');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE inventory_movement_type AS ENUM (
    'PURCHASE',
    'SALE',
    'RETURN',
    'ADJUSTMENT',
    'DAMAGE',
    'THEFT',
    'EXPIRY'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- SECTION 3: CORE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1: USERS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  uuid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
  phone VARCHAR(15) NOT NULL UNIQUE,
  email VARCHAR(255) UNIQUE,
  name VARCHAR(255),
  role user_role NOT NULL DEFAULT 'customer',
  status user_status NOT NULL DEFAULT 'active',
  
  -- Authentication
  refresh_token_hash TEXT,
  mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  mfa_secret TEXT,
  mfa_backup_codes JSONB,
  last_login_at TIMESTAMPTZ,
  login_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ,
  
  -- Profile
  avatar_url TEXT,
  date_of_birth DATE,
  gender VARCHAR(10),
  
  -- Metadata
  device_token TEXT,
  fcm_token TEXT,
  app_version VARCHAR(20),
  platform VARCHAR(20),
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  deleted_by BIGINT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE deleted_at IS NULL AND email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_uuid ON users(uuid);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Full-text search on name
CREATE INDEX IF NOT EXISTS idx_users_name_trgm ON users USING gin(name gin_trgm_ops) WHERE deleted_at IS NULL;

COMMENT ON TABLE users IS 'Core user table supporting customers, riders, admins, and support staff';

-- ----------------------------------------------------------------------------
-- 3.2: ADDRESSES MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS addresses (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Address details
  label VARCHAR(50), -- 'Home', 'Office', 'Other'
  full_name VARCHAR(255),
  phone VARCHAR(15),
  
  address_line_1 VARCHAR(500) NOT NULL,
  address_line_2 VARCHAR(500),
  landmark VARCHAR(255),
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100) NOT NULL,
  pincode VARCHAR(10) NOT NULL,
  country VARCHAR(100) NOT NULL DEFAULT 'India',
  
  -- Geolocation
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  location GEOGRAPHY(POINT, 4326), -- PostGIS point
  
  -- Metadata
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  delivery_instructions TEXT,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_addresses_pincode ON addresses(pincode) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_addresses_location ON addresses USING GIST(location) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_addresses_default ON addresses(user_id, is_default) WHERE deleted_at IS NULL AND is_default = TRUE;

COMMENT ON TABLE addresses IS 'User delivery addresses with geolocation support';

-- ----------------------------------------------------------------------------
-- 3.3: CATEGORIES MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  parent_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  
  -- Category details
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  image_url TEXT,
  icon_url TEXT,
  
  -- Hierarchy & ordering
  sort_order INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 0,
  path TEXT, -- Materialized path for hierarchy
  
  -- Visibility
  active BOOLEAN NOT NULL DEFAULT TRUE,
  featured BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- SEO
  meta_title VARCHAR(255),
  meta_description TEXT,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_categories_path ON categories(path) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_categories_name_trgm ON categories USING gin(name gin_trgm_ops) WHERE deleted_at IS NULL;

COMMENT ON TABLE categories IS 'Hierarchical product categories with soft delete';

-- ----------------------------------------------------------------------------
-- 3.4: PRODUCTS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS products (
  id BIGSERIAL PRIMARY KEY,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  
  -- Product details
  name VARCHAR(500) NOT NULL,
  slug VARCHAR(500) NOT NULL UNIQUE,
  description TEXT,
  short_description VARCHAR(500),
  
  -- Pricing
  price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  mrp NUMERIC(10, 2) CHECK (mrp IS NULL OR mrp >= price),
  cost_price NUMERIC(10, 2) CHECK (cost_price IS NULL OR cost_price >= 0),
  
  -- Inventory
  sku VARCHAR(100) UNIQUE,
  barcode VARCHAR(100) UNIQUE,
  unit VARCHAR(50), -- 'kg', 'g', 'piece', 'liter'
  unit_value NUMERIC(10, 3), -- e.g., 0.5 for 500g
  min_order_quantity INTEGER NOT NULL DEFAULT 1,
  max_order_quantity INTEGER,
  
  -- Media
  image_url TEXT,
  images JSONB, -- Array of image URLs
  video_url TEXT,
  
  -- Attributes
  attributes JSONB, -- {weight: '500g', shelf_life: '3 days', storage: 'Refrigerated'}
  tags TEXT[], -- {'chicken', 'halal', 'fresh'}
  
  -- Status
  active BOOLEAN NOT NULL DEFAULT TRUE,
  featured BOOLEAN NOT NULL DEFAULT FALSE,
  is_bestseller BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- SEO
  meta_title VARCHAR(255),
  meta_description TEXT,
  
  -- Analytics
  view_count INTEGER NOT NULL DEFAULT 0,
  order_count INTEGER NOT NULL DEFAULT 0,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_slug ON products(slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_active ON products(active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_featured ON products(featured) WHERE deleted_at IS NULL AND featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku) WHERE deleted_at IS NULL AND sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode) WHERE deleted_at IS NULL AND barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin(name gin_trgm_ops) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_tags ON products USING gin(tags) WHERE deleted_at IS NULL;

COMMENT ON TABLE products IS 'Product catalog with inventory tracking and rich metadata';

-- ----------------------------------------------------------------------------
-- 3.5: INVENTORY MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS inventory (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  
  -- Stock levels
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  reserved_quantity INTEGER NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
  available_quantity INTEGER GENERATED ALWAYS AS (quantity - reserved_quantity) STORED,
  
  -- Thresholds
  reorder_level INTEGER NOT NULL DEFAULT 10,
  reorder_quantity INTEGER NOT NULL DEFAULT 50,
  
  -- Batch tracking
  batch_number VARCHAR(100),
  manufacture_date DATE,
  expiry_date DATE,
  
  -- Location
  warehouse_location VARCHAR(100),
  shelf_location VARCHAR(100),
  
  -- Timestamps
  last_restocked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_product_id ON inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_low_stock ON inventory(product_id) WHERE available_quantity <= reorder_level;
CREATE INDEX IF NOT EXISTS idx_inventory_expiry ON inventory(expiry_date) WHERE expiry_date IS NOT NULL;

COMMENT ON TABLE inventory IS 'Real-time inventory tracking with reservations and reorder alerts';

-- Inventory movement log
CREATE TABLE IF NOT EXISTS inventory_movements (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  movement_type inventory_movement_type NOT NULL,
  
  -- Quantities
  quantity INTEGER NOT NULL,
  previous_quantity INTEGER NOT NULL,
  new_quantity INTEGER NOT NULL,
  
  -- Reference
  reference_type VARCHAR(50), -- 'order', 'adjustment', 'purchase_order'
  reference_id BIGINT,
  
  -- Details
  reason TEXT,
  notes TEXT,
  
  -- Audit
  created_by BIGINT REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions for current and next 12 months
CREATE TABLE IF NOT EXISTS inventory_movements_2026_06 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS inventory_movements_2026_07 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS inventory_movements_2026_08 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS inventory_movements_2026_09 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS inventory_movements_2026_10 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS inventory_movements_2026_11 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS inventory_movements_2026_12 PARTITION OF inventory_movements
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes on partitions
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_type ON inventory_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_reference ON inventory_movements(reference_type, reference_id);

COMMENT ON TABLE inventory_movements IS 'Audit log for all inventory changes (partitioned by month)';

-- ----------------------------------------------------------------------------
-- 3.6: COUPONS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS coupons (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  
  -- Discount details
  discount_type discount_type NOT NULL,
  discount_value NUMERIC(10, 2) NOT NULL CHECK (discount_value >= 0),
  max_discount NUMERIC(10, 2),
  
  -- Conditions
  min_order_value NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (min_order_value >= 0),
  applicability coupon_applicability NOT NULL DEFAULT 'ALL',
  applicable_categories BIGINT[],
  applicable_users BIGINT[],
  
  -- Usage limits
  max_uses INTEGER,
  max_uses_per_user INTEGER NOT NULL DEFAULT 1,
  used_count INTEGER NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  
  -- Validity
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_to TIMESTAMPTZ NOT NULL,
  
  -- Status
  active BOOLEAN NOT NULL DEFAULT TRUE,
  
  -- Metadata
  title VARCHAR(255),
  description TEXT,
  terms_and_conditions TEXT,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_coupons_code ON coupons(UPPER(code)) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_coupons_validity ON coupons(valid_from, valid_to) WHERE deleted_at IS NULL;

COMMENT ON TABLE coupons IS 'Promotional coupons with flexible applicability rules';

-- Coupon usage tracking
CREATE TABLE IF NOT EXISTS coupon_usage (
  id BIGSERIAL PRIMARY KEY,
  coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  
  discount_amount NUMERIC(10, 2) NOT NULL,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_coupon_usage_coupon_id ON coupon_usage(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_user_id ON coupon_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_order_id ON coupon_usage(order_id);

COMMENT ON TABLE coupon_usage IS 'Track individual coupon redemptions';

-- ----------------------------------------------------------------------------
-- 3.7: ORDERS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  order_number VARCHAR(50) NOT NULL UNIQUE,
  customer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  address_id BIGINT REFERENCES addresses(id) ON DELETE SET NULL,
  
  -- Status
  status order_status NOT NULL DEFAULT 'PENDING',
  
  -- Pricing
  subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
  discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
  tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
  
  -- Coupon
  coupon_id BIGINT REFERENCES coupons(id) ON DELETE SET NULL,
  coupon_code VARCHAR(50),
  
  -- Address snapshot (JSONB for immutability)
  address JSONB NOT NULL,
  
  -- Delivery
  delivery_slot_id BIGINT,
  scheduled_delivery_date DATE,
  scheduled_delivery_time_start TIME,
  scheduled_delivery_time_end TIME,
  actual_delivery_at TIMESTAMPTZ,
  
  -- Payment
  payment_mode payment_mode NOT NULL DEFAULT 'COD',
  
  -- Notes
  customer_notes TEXT,
  internal_notes TEXT,
  cancellation_reason TEXT,
  
  -- Timestamps
  placed_at TIMESTAMPTZ,
  confirmed_at TIMESTAMPTZ,
  packed_at TIMESTAMPTZ,
  out_for_delivery_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions for current and next 12 months
CREATE TABLE IF NOT EXISTS orders_2026_06 PARTITION OF orders
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS orders_2026_07 PARTITION OF orders
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS orders_2026_08 PARTITION OF orders
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS orders_2026_09 PARTITION OF orders
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS orders_2026_10 PARTITION OF orders
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS orders_2026_11 PARTITION OF orders
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS orders_2026_12 PARTITION OF orders
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes on partitioned table
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_payment_mode ON orders(payment_mode);

COMMENT ON TABLE orders IS 'Customer orders (partitioned by month for scalability)';

-- ----------------------------------------------------------------------------
-- 3.8: ORDER ITEMS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  
  -- Product snapshot (at time of order)
  product_name VARCHAR(500) NOT NULL,
  product_image TEXT,
  sku VARCHAR(100),
  
  -- Pricing
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
  mrp NUMERIC(10, 2),
  discount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  tax NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_price NUMERIC(10, 2) NOT NULL CHECK (total_price >= 0),
  
  -- Metadata
  unit VARCHAR(50),
  attributes JSONB,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions matching orders table
CREATE TABLE IF NOT EXISTS order_items_2026_06 PARTITION OF order_items
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS order_items_2026_07 PARTITION OF order_items
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS order_items_2026_08 PARTITION OF order_items
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS order_items_2026_09 PARTITION OF order_items
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS order_items_2026_10 PARTITION OF order_items
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS order_items_2026_11 PARTITION OF order_items
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS order_items_2026_12 PARTITION OF order_items
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

COMMENT ON TABLE order_items IS 'Line items for orders (partitioned by month)';

-- ----------------------------------------------------------------------------
-- 3.9: PAYMENTS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payments (
  id BIGSERIAL PRIMARY KEY,
  payment_id VARCHAR(100) NOT NULL UNIQUE,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  
  -- Amount
  amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'INR',
  
  -- Payment details
  payment_mode payment_mode NOT NULL,
  payment_gateway payment_gateway,
  status payment_status NOT NULL DEFAULT 'PENDING',
  
  -- Gateway references
  gateway_transaction_id VARCHAR(255),
  gateway_order_id VARCHAR(255),
  gateway_payment_id VARCHAR(255),
  
  -- Gateway response
  gateway_response JSONB,
  callback_data JSONB,
  
  -- Refund
  refund_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  refund_initiated_at TIMESTAMPTZ,
  refund_completed_at TIMESTAMPTZ,
  refund_reference VARCHAR(255),
  
  -- Metadata
  payment_method VARCHAR(50), -- 'UPI', 'Card', 'NetBanking'
  failure_reason TEXT,
  
  -- Timestamps
  initiated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE IF NOT EXISTS payments_2026_06 PARTITION OF payments
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS payments_2026_07 PARTITION OF payments
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS payments_2026_08 PARTITION OF payments
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS payments_2026_09 PARTITION OF payments
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS payments_2026_10 PARTITION OF payments
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS payments_2026_11 PARTITION OF payments
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS payments_2026_12 PARTITION OF payments
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_payment_id ON payments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_gateway_transaction_id ON payments(gateway_transaction_id);

COMMENT ON TABLE payments IS 'Payment transactions with gateway integration (partitioned by month)';

-- ----------------------------------------------------------------------------
-- 3.10: RIDERS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS delivery_partners (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  
  -- Status
  availability rider_availability NOT NULL DEFAULT 'OFFLINE',
  approved BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- Location (current)
  current_lat NUMERIC(10, 7),
  current_lng NUMERIC(10, 7),
  current_location GEOGRAPHY(POINT, 4326),
  location_updated_at TIMESTAMPTZ,
  
  -- Vehicle
  vehicle_type VARCHAR(50), -- 'Bike', 'Scooter', 'Car'
  vehicle_number VARCHAR(20),
  licence_number VARCHAR(20),
  
  -- Documents
  documents JSONB, -- {licence_url, rc_url, insurance_url, photo_url}
  
  -- Banking
  bank_name VARCHAR(100),
  account_number VARCHAR(30),
  ifsc_code VARCHAR(20),
  upi_id VARCHAR(100),
  
  -- Performance metrics
  total_deliveries INTEGER NOT NULL DEFAULT 0,
  successful_deliveries INTEGER NOT NULL DEFAULT 0,
  cancelled_deliveries INTEGER NOT NULL DEFAULT 0,
  average_rating NUMERIC(3, 2) DEFAULT 0 CHECK (average_rating >= 0 AND average_rating <= 5),
  rating_count INTEGER NOT NULL DEFAULT 0,
  
  -- Earnings
  total_earnings NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (total_earnings >= 0),
  pending_earnings NUMERIC(10, 2) NOT NULL DEFAULT 0,
  withdrawn_earnings NUMERIC(10, 2) NOT NULL DEFAULT 0,
  
  -- Working hours
  shift_start TIME,
  shift_end TIME,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_delivery_partners_user_id ON delivery_partners(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_partners_availability ON delivery_partners(availability) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_partners_approved ON delivery_partners(approved) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_partners_location ON delivery_partners USING GIST(current_location) WHERE deleted_at IS NULL;

COMMENT ON TABLE delivery_partners IS 'Delivery rider profiles with performance tracking';

-- ----------------------------------------------------------------------------
-- 3.11: RIDER LOCATIONS MODULE (Historical Tracking)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rider_location_history (
  id BIGSERIAL PRIMARY KEY,
  rider_id BIGINT NOT NULL REFERENCES delivery_partners(id) ON DELETE CASCADE,
  order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  
  -- Location
  latitude NUMERIC(10, 7) NOT NULL,
  longitude NUMERIC(10, 7) NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  
  -- Metadata
  accuracy NUMERIC(10, 2), -- meters
  speed NUMERIC(10, 2), -- km/h
  bearing NUMERIC(5, 2), -- degrees
  
  -- Timestamps
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE IF NOT EXISTS rider_location_history_2026_06 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS rider_location_history_2026_07 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS rider_location_history_2026_08 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS rider_location_history_2026_09 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS rider_location_history_2026_10 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS rider_location_history_2026_11 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS rider_location_history_2026_12 PARTITION OF rider_location_history
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_rider_location_history_rider_id ON rider_location_history(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_location_history_order_id ON rider_location_history(order_id);
CREATE INDEX IF NOT EXISTS idx_rider_location_history_location ON rider_location_history USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_rider_location_history_recorded_at ON rider_location_history(recorded_at);

COMMENT ON TABLE rider_location_history IS 'GPS breadcrumb trail for riders (partitioned by month)';

-- Order assignments
CREATE TABLE IF NOT EXISTS order_assignments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  delivery_partner_id BIGINT NOT NULL REFERENCES delivery_partners(id) ON DELETE RESTRICT,
  
  status assignment_status NOT NULL DEFAULT 'ASSIGNED',
  
  -- Pickup/Delivery
  pickup_otp VARCHAR(6),
  delivery_otp VARCHAR(6),
  
  -- Proof of delivery
  delivery_image_url TEXT,
  delivery_signature_url TEXT,
  delivery_notes TEXT,
  
  -- Earnings
  delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 0,
  tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_earning NUMERIC(10, 2) GENERATED ALWAYS AS (delivery_fee + tip_amount) STORED,
  
  -- Timestamps
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  picked_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_order_assignments_order_id ON order_assignments(order_id);
CREATE INDEX IF NOT EXISTS idx_order_assignments_delivery_partner_id ON order_assignments(delivery_partner_id);
CREATE INDEX IF NOT EXISTS idx_order_assignments_status ON order_assignments(status);

COMMENT ON TABLE order_assignments IS 'Rider-order assignment tracking with earnings';

-- ----------------------------------------------------------------------------
-- 3.12: NOTIFICATIONS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Notification details
  type notification_type NOT NULL,
  channel notification_channel NOT NULL DEFAULT 'IN_APP',
  
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  image_url TEXT,
  
  -- Action
  action_url TEXT,
  action_data JSONB,
  
  -- Reference
  reference_type VARCHAR(50), -- 'order', 'payment', 'promotion'
  reference_id BIGINT,
  
  -- Status
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  
  -- Delivery status
  sent BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ,
  delivery_status VARCHAR(50), -- 'delivered', 'failed', 'clicked'
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  scheduled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE IF NOT EXISTS notifications_2026_06 PARTITION OF notifications
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS notifications_2026_07 PARTITION OF notifications
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS notifications_2026_08 PARTITION OF notifications
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS notifications_2026_09 PARTITION OF notifications
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS notifications_2026_10 PARTITION OF notifications
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS notifications_2026_11 PARTITION OF notifications
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS notifications_2026_12 PARTITION OF notifications
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE deleted_at IS NULL AND is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_reference ON notifications(reference_type, reference_id);

COMMENT ON TABLE notifications IS 'Multi-channel notifications (partitioned by month)';

-- ----------------------------------------------------------------------------
-- 3.13: REVIEWS MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS reviews (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id BIGINT REFERENCES products(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivery_partner_id BIGINT REFERENCES delivery_partners(id) ON DELETE SET NULL,
  
  -- Rating (1-5)
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  
  -- Review
  review_text TEXT,
  images TEXT[], -- Array of image URLs
  
  -- Metadata
  is_verified_purchase BOOLEAN NOT NULL DEFAULT TRUE,
  is_approved BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- Moderation
  moderation_notes TEXT,
  moderated_by BIGINT REFERENCES users(id),
  moderated_at TIMESTAMPTZ,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reviews_order_id ON reviews(order_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON reviews(product_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_rider_id ON reviews(delivery_partner_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_approved ON reviews(is_approved) WHERE deleted_at IS NULL;

COMMENT ON TABLE reviews IS 'Product and delivery partner reviews';

-- ----------------------------------------------------------------------------
-- 3.14: WALLET MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS wallets (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  
  -- Balance
  balance NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  locked_balance NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (locked_balance >= 0),
  available_balance NUMERIC(10, 2) GENERATED ALWAYS AS (balance - locked_balance) STORED,
  
  -- Metadata
  currency VARCHAR(3) NOT NULL DEFAULT 'INR',
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);

COMMENT ON TABLE wallets IS 'User wallet for cashback, refunds, and credits';

-- Wallet transactions
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id BIGSERIAL PRIMARY KEY,
  wallet_id BIGINT NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Transaction
  transaction_type wallet_transaction_type NOT NULL,
  amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  
  -- Balance snapshot
  balance_before NUMERIC(10, 2) NOT NULL,
  balance_after NUMERIC(10, 2) NOT NULL,
  
  -- Reference
  reference_type VARCHAR(50), -- 'order', 'refund', 'referral', 'cashback'
  reference_id BIGINT,
  
  -- Description
  description TEXT,
  metadata JSONB,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_06 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_07 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_08 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_09 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_10 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_11 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_12 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_reference ON wallet_transactions(reference_type, reference_id);

COMMENT ON TABLE wallet_transactions IS 'Wallet transaction history (partitioned by month)';

-- ----------------------------------------------------------------------------
-- 3.15: REFERRAL SYSTEM MODULE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS referral_codes (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  
  -- Code
  code VARCHAR(20) NOT NULL UNIQUE,
  
  -- Rewards
  referrer_reward NUMERIC(10, 2) NOT NULL DEFAULT 50,
  referee_reward NUMERIC(10, 2) NOT NULL DEFAULT 50,
  
  -- Usage
  total_referrals INTEGER NOT NULL DEFAULT 0,
  successful_referrals INTEGER NOT NULL DEFAULT 0,
  
  -- Validity
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_to TIMESTAMPTZ,
  max_uses INTEGER,
  
  active BOOLEAN NOT NULL DEFAULT TRUE,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(UPPER(code));
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_active ON referral_codes(active);

COMMENT ON TABLE referral_codes IS 'User referral codes with rewards';

-- Referrals
CREATE TABLE IF NOT EXISTS referrals (
  id BIGSERIAL PRIMARY KEY,
  referral_code_id BIGINT NOT NULL REFERENCES referral_codes(id) ON DELETE CASCADE,
  referrer_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  referee_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Status
  status referral_status NOT NULL DEFAULT 'PENDING',
  
  -- Rewards
  referrer_reward NUMERIC(10, 2) NOT NULL,
  referee_reward NUMERIC(10, 2) NOT NULL,
  
  -- Completion criteria
  referee_first_order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  min_order_value NUMERIC(10, 2) NOT NULL DEFAULT 0,
  
  -- Timestamps
  referred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referral_code_id ON referrals(referral_code_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referee_id ON referrals(referee_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON referrals(status);

COMMENT ON TABLE referrals IS 'Individual referral tracking';

-- ============================================================================
-- SECTION 4: SUPPORTING TABLES
-- ============================================================================

-- Banners
CREATE TABLE IF NOT EXISTS banners (
  id BIGSERIAL PRIMARY KEY,
  title VARCHAR(255),
  image_url TEXT NOT NULL,
  mobile_image_url TEXT,
  
  -- Action
  action_type VARCHAR(50), -- 'category', 'product', 'url', 'none'
  action_value TEXT,
  
  -- Display
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  
  -- Scheduling
  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,
  
  -- Soft delete
  deleted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_banners_active ON banners(active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_banners_sort_order ON banners(sort_order);

COMMENT ON TABLE banners IS 'Homepage promotional banners';

-- Delivery slots
CREATE TABLE IF NOT EXISTS delivery_slots (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_date DATE NOT NULL,
  
  -- Capacity
  capacity INTEGER NOT NULL DEFAULT 20,
  booked INTEGER NOT NULL DEFAULT 0 CHECK (booked >= 0),
  available INTEGER GENERATED ALWAYS AS (capacity - booked) STORED,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_slots_date_name ON delivery_slots(slot_date, name);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_date ON delivery_slots(slot_date);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_active ON delivery_slots(is_active, slot_date);

COMMENT ON TABLE delivery_slots IS 'Daily delivery time slots';

-- OTP logs
CREATE TABLE IF NOT EXISTS otp_logs (
  id BIGSERIAL PRIMARY KEY,
  phone VARCHAR(15) NOT NULL,
  otp VARCHAR(6) NOT NULL,
  
  -- Gateway
  template_id TEXT,
  msg91_response JSONB,
  
  -- Status
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  attempts INTEGER NOT NULL DEFAULT 0,
  
  -- Timestamps
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE IF NOT EXISTS otp_logs_2026_06 PARTITION OF otp_logs
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS otp_logs_2026_07 PARTITION OF otp_logs
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS otp_logs_2026_08 PARTITION OF otp_logs
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_otp_logs_phone ON otp_logs(phone, created_at DESC);

COMMENT ON TABLE otp_logs IS 'OTP verification audit trail (partitioned)';

-- App settings
CREATE TABLE IF NOT EXISTS app_settings (
  key VARCHAR(100) PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE app_settings IS 'Key-value store for app configuration';

-- ============================================================================
-- SECTION 5: AUDIT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_users (
  audit_id BIGSERIAL PRIMARY KEY,
  operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
  user_id BIGINT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  changed_by BIGINT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (changed_at);

CREATE TABLE IF NOT EXISTS audit_users_2026_06 PARTITION OF audit_users
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE INDEX IF NOT EXISTS idx_audit_users_user_id ON audit_users(user_id);

CREATE TABLE IF NOT EXISTS audit_orders (
  audit_id BIGSERIAL PRIMARY KEY,
  operation VARCHAR(10) NOT NULL,
  order_id BIGINT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  changed_by BIGINT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (changed_at);

CREATE TABLE IF NOT EXISTS audit_orders_2026_06 PARTITION OF audit_orders
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE INDEX IF NOT EXISTS idx_audit_orders_order_id ON audit_orders(order_id);

CREATE TABLE IF NOT EXISTS audit_payments (
  audit_id BIGSERIAL PRIMARY KEY,
  operation VARCHAR(10) NOT NULL,
  payment_id BIGINT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  changed_by BIGINT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (changed_at);

CREATE TABLE IF NOT EXISTS audit_payments_2026_06 PARTITION OF audit_payments
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE INDEX IF NOT EXISTS idx_audit_payments_payment_id ON audit_payments(payment_id);

COMMENT ON TABLE audit_users IS 'Audit trail for user table changes';
COMMENT ON TABLE audit_orders IS 'Audit trail for order table changes';
COMMENT ON TABLE audit_payments IS 'Audit trail for payment table changes';

-- ============================================================================
-- SECTION 6: TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER tr_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_addresses_updated_at BEFORE UPDATE ON addresses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_coupons_updated_at BEFORE UPDATE ON coupons
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_delivery_partners_updated_at BEFORE UPDATE ON delivery_partners
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_order_assignments_updated_at BEFORE UPDATE ON order_assignments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_number IS NULL THEN
    NEW.order_number := 'MVT' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEW.id::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_orders_generate_number BEFORE INSERT ON orders
  FOR EACH ROW EXECUTE FUNCTION generate_order_number();

-- Auto-generate referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.code IS NULL THEN
    NEW.code := 'REF' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 8));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_referral_codes_generate BEFORE INSERT ON referral_codes
  FOR EACH ROW EXECUTE FUNCTION generate_referral_code();

-- Update product order count
CREATE OR REPLACE FUNCTION update_product_order_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products 
  SET order_count = order_count + NEW.quantity
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_order_items_product_count AFTER INSERT ON order_items
  FOR EACH ROW EXECUTE FUNCTION update_product_order_count();

-- Update wallet balance on transaction
CREATE OR REPLACE FUNCTION update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transaction_type IN ('CREDIT', 'REFUND', 'CASHBACK', 'REFERRAL_BONUS') THEN
    UPDATE wallets SET balance = balance + NEW.amount WHERE id = NEW.wallet_id;
  ELSIF NEW.transaction_type IN ('DEBIT', 'WITHDRAWAL') THEN
    UPDATE wallets SET balance = balance - NEW.amount WHERE id = NEW.wallet_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_wallet_transactions_update_balance AFTER INSERT ON wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION update_wallet_balance();

-- Audit trigger for users
CREATE OR REPLACE FUNCTION audit_users_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_users (operation, user_id, new_data)
    VALUES ('INSERT', NEW.id, to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_users (operation, user_id, old_data, new_data)
    VALUES ('UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_users (operation, user_id, old_data)
    VALUES ('DELETE', OLD.id, to_jsonb(OLD));
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_audit_users AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW EXECUTE FUNCTION audit_users_changes();

-- Audit trigger for orders
CREATE OR REPLACE FUNCTION audit_orders_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_orders (operation, order_id, new_data)
    VALUES ('INSERT', NEW.id, to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_orders (operation, order_id, old_data, new_data)
    VALUES ('UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_orders (operation, order_id, old_data)
    VALUES ('DELETE', OLD.id, to_jsonb(OLD));
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_audit_orders AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW EXECUTE FUNCTION audit_orders_changes();

-- Audit trigger for payments
CREATE OR REPLACE FUNCTION audit_payments_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_payments (operation, payment_id, new_data)
    VALUES ('INSERT', NEW.id, to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_payments (operation, payment_id, old_data, new_data)
    VALUES ('UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_payments (operation, payment_id, old_data)
    VALUES ('DELETE', OLD.id, to_jsonb(OLD));
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_audit_payments AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW EXECUTE FUNCTION audit_payments_changes();

-- ============================================================================
-- SECTION 7: UTILITY FUNCTIONS
-- ============================================================================

-- Auto-generate delivery slots (14 days rolling window)
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
      ('Afternoon', '12:00:00', '16:00:00', d, 20, 0, true),
      ('Evening', '17:00:00', '21:00:00', d, 20, 0, true)
    ON CONFLICT (slot_date, name) DO NOTHING;
    d := d + 1;
  END LOOP;
END;
$$;

-- Calculate distance between two points (Haversine formula)
CREATE OR REPLACE FUNCTION calculate_distance(
  lat1 NUMERIC, lon1 NUMERIC,
  lat2 NUMERIC, lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
  R NUMERIC := 6371; -- Earth radius in km
  dLat NUMERIC;
  dLon NUMERIC;
  a NUMERIC;
  c NUMERIC;
BEGIN
  dLat := RADIANS(lat2 - lat1);
  dLon := RADIANS(lon2 - lon1);
  a := SIN(dLat/2) * SIN(dLat/2) + COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * SIN(dLon/2) * SIN(dLon/2);
  c := 2 * ATAN2(SQRT(a), SQRT(1-a));
  RETURN R * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Find available riders near a location
CREATE OR REPLACE FUNCTION find_available_riders(
  target_lat NUMERIC,
  target_lon NUMERIC,
  radius_km NUMERIC DEFAULT 5
)
RETURNS TABLE (
  rider_id BIGINT,
  user_id BIGINT,
  distance_km NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    dp.id,
    dp.user_id,
    ST_Distance(
      dp.current_location::geography,
      ST_MakePoint(target_lon, target_lat)::geography
    ) / 1000 AS distance_km
  FROM delivery_partners dp
  WHERE
    dp.availability = 'AVAILABLE'
    AND dp.approved = TRUE
    AND dp.deleted_at IS NULL
    AND ST_DWithin(
      dp.current_location::geography,
      ST_MakePoint(target_lon, target_lat)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

-- Soft delete helper
CREATE OR REPLACE FUNCTION soft_delete(
  table_name TEXT,
  record_id BIGINT,
  deleted_by_user_id BIGINT
)
RETURNS BOOLEAN AS $$
BEGIN
  EXECUTE format('UPDATE %I SET deleted_at = NOW(), deleted_by = $1 WHERE id = $2 AND deleted_at IS NULL', table_name)
  USING deleted_by_user_id, record_id;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 8: INITIAL DATA
-- ============================================================================

-- Insert default admin user (password should be changed immediately)
INSERT INTO users (phone, name, role, status)
VALUES ('+919999999999', 'System Admin', 'admin', 'active')
ON CONFLICT (phone) DO NOTHING;

-- Generate initial delivery slots
SELECT auto_generate_delivery_slots();

-- Default app settings
INSERT INTO app_settings (key, value, description)
VALUES
  ('store_name', '"Meatvo"', 'Store name'),
  ('store_open', 'true', 'Is store open for orders'),
  ('min_order_value', '99', 'Minimum order value in INR'),
  ('delivery_fee', '20', 'Delivery fee in INR'),
  ('free_delivery_above', '499', 'Free delivery above this amount'),
  ('gst_rate', '5', 'GST percentage'),
  ('service_radius_km', '10', 'Service radius in kilometers'),
  ('default_slot_capacity', '20', 'Default delivery slot capacity')
ON CONFLICT (key) DO NOTHING;

COMMIT;

-- ============================================================================
-- PARTITION MAINTENANCE SCRIPT (Run monthly)
-- ============================================================================

/*
-- Create new partitions for next month (run at start of each month)

-- Example for July 2027:
CREATE TABLE IF NOT EXISTS orders_2027_07 PARTITION OF orders
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS order_items_2027_07 PARTITION OF order_items
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS payments_2027_07 PARTITION OF payments
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS inventory_movements_2027_07 PARTITION OF inventory_movements
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS notifications_2027_07 PARTITION OF notifications
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS wallet_transactions_2027_07 PARTITION OF wallet_transactions
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS rider_location_history_2027_07 PARTITION OF rider_location_history
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS otp_logs_2027_07 PARTITION OF otp_logs
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS audit_users_2027_07 PARTITION OF audit_users
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS audit_orders_2027_07 PARTITION OF audit_orders
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');

CREATE TABLE IF NOT EXISTS audit_payments_2027_07 PARTITION OF audit_payments
  FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
*/

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
