# Meatvo Database Migration Guide

## Migration from Old Schema to Complete Schema

This guide walks through migrating from the existing `schema.sql` to the new comprehensive `schema_complete.sql`.

---

## Pre-Migration Checklist

- [ ] Backup existing database
- [ ] Test migration on staging environment
- [ ] Schedule maintenance window (2-4 hours recommended)
- [ ] Notify users of downtime
- [ ] Prepare rollback plan
- [ ] Verify disk space (require 2x current DB size)

---

## Step 1: Backup Current Database

### Full Backup
```bash
# Create backup directory
mkdir -p /backups/meatvo/$(date +%Y%m%d)

# Full database backup
pg_dump -Fc -h localhost -U postgres -d meatvo_db \
  > /backups/meatvo/$(date +%Y%m%d)/meatvo_full_$(date +%Y%m%d_%H%M%S).dump

# Backup schema only
pg_dump -s -h localhost -U postgres -d meatvo_db \
  > /backups/meatvo/$(date +%Y%m%d)/meatvo_schema_$(date +%Y%m%d_%H%M%S).sql

# Verify backup
pg_restore --list /backups/meatvo/$(date +%Y%m%d)/meatvo_full_*.dump | head -20
```

### Table Row Counts (for verification)
```sql
-- Save current row counts
\copy (SELECT 
  schemaname, 
  tablename, 
  n_live_tup as row_count 
FROM pg_stat_user_tables 
ORDER BY tablename) 
TO '/backups/meatvo/$(date +%Y%m%d)/row_counts_before.csv' CSV HEADER;
```

---

## Step 2: Analyze Current Schema

### Identify Schema Differences
```bash
# Compare schemas
diff -u schema.sql schema_complete.sql > schema_diff.patch
```

### Key Changes in New Schema

| Change | Impact | Action Required |
|--------|--------|-----------------|
| **users table** | Added columns: uuid, email, status, device_token, fcm_token | Backfill UUIDs, set default status |
| **addresses table** | New table (was JSONB in orders) | Extract addresses from orders.address |
| **products table** | Added: slug, sku, barcode, tags[], attributes, view_count | Generate slugs/SKUs |
| **inventory table** | New table (was stock column in products) | Migrate products.stock → inventory.quantity |
| **inventory_movements** | New partitioned table | Historical tracking starts post-migration |
| **payments table** | New partitioned table | Extract from order context |
| **delivery_partners** | Renamed from delivery_partners, added columns | Migrate + add new fields |
| **rider_location_history** | New partitioned table | Real-time tracking starts post-migration |
| **wallets** | New table | Create wallets for all users |
| **wallet_transactions** | New partitioned table | Historical tracking starts post-migration |
| **referral_codes** | New table | Generate codes for existing users |
| **referrals** | New table | Track future referrals |
| **reviews** | New table | Product/rider reviews start post-migration |
| **notifications** | New partitioned table | Push notification history |
| **banners** | Updated with new columns | Add action_type, action_value |
| **audit tables** | New partitioned tables | Audit trail starts post-migration |

---

## Step 3: Migration Strategy

### Option A: Blue-Green Deployment (Recommended)

1. Create new database with complete schema
2. Migrate data with zero downtime
3. Switch over during maintenance window

### Option B: In-Place Migration

1. Run migration scripts on existing database
2. Requires downtime

---

## Step 4: Blue-Green Migration Steps

### 4.1 Create New Database
```bash
# Create new database
createdb -h localhost -U postgres meatvo_db_new

# Install extensions
psql -h localhost -U postgres -d meatvo_db_new <<EOF
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
EOF

# Load complete schema
psql -h localhost -U postgres -d meatvo_db_new < backend/src/db/schema_complete.sql
```

### 4.2 Migrate Core Tables
```sql
-- Connect to new database
\c meatvo_db_new

-- 1. Migrate users
INSERT INTO users (id, phone, name, role, refresh_token_hash, mfa_enabled, mfa_secret, mfa_backup_codes, created_at)
SELECT 
  id, 
  phone, 
  name, 
  role, 
  refresh_token_hash, 
  mfa_enabled, 
  mfa_secret, 
  mfa_backup_codes, 
  created_at
FROM dblink('dbname=meatvo_db', 'SELECT * FROM users') 
AS old_users(
  id bigint, 
  phone text, 
  name text, 
  role text, 
  refresh_token_hash text, 
  mfa_enabled boolean, 
  mfa_secret text, 
  mfa_backup_codes jsonb, 
  created_at timestamptz
);

-- Generate UUIDs for existing users
UPDATE users SET uuid = uuid_generate_v4() WHERE uuid IS NULL;

-- Set default status
UPDATE users SET status = 'active' WHERE status IS NULL;

-- 2. Extract addresses from orders
INSERT INTO addresses (user_id, address_line_1, city, state, pincode, latitude, longitude, is_default, created_at)
SELECT DISTINCT ON (customer_id)
  customer_id,
  address->>'line1',
  address->>'city',
  address->>'state',
  address->>'pincode',
  (address->>'lat')::numeric,
  (address->>'lng')::numeric,
  true,
  MIN(created_at) OVER (PARTITION BY customer_id)
FROM dblink('dbname=meatvo_db', 'SELECT customer_id, address, created_at FROM orders') 
AS old_orders(customer_id bigint, address jsonb, created_at timestamptz)
WHERE address IS NOT NULL;

-- Set location geography
UPDATE addresses 
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 3. Migrate categories
INSERT INTO categories (id, name, image_url, sort_order, active)
SELECT id, name, image_url, COALESCE(sort_order, 0), COALESCE(active, true)
FROM dblink('dbname=meatvo_db', 'SELECT id, name, image_url, sort_order, active FROM categories') 
AS old_categories(id bigint, name text, image_url text, sort_order int, active boolean);

-- Generate slugs
UPDATE categories SET slug = LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '-', 'g'));

-- 4. Migrate products
INSERT INTO products (id, category_id, name, description, price, mrp, image_url, active)
SELECT 
  id, 
  category_id, 
  name, 
  description, 
  price, 
  mrp, 
  image_url, 
  COALESCE(active, true)
FROM dblink('dbname=meatvo_db', 'SELECT * FROM products') 
AS old_products(id bigint, category_id bigint, name text, description text, price numeric, mrp numeric, image_url text, stock int, unit text, active boolean);

-- Generate slugs and SKUs
UPDATE products SET slug = LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '-', 'g'));
UPDATE products SET sku = 'SKU' || LPAD(id::text, 8, '0');

-- 5. Migrate inventory (from products.stock)
INSERT INTO inventory (product_id, quantity)
SELECT id, COALESCE(stock, 0)
FROM dblink('dbname=meatvo_db', 'SELECT id, stock FROM products') 
AS old_products(id bigint, stock int);

-- 6. Migrate coupons
INSERT INTO coupons (id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active)
SELECT id, code, discount_type, discount_value, min_order_value, max_uses, used_count, COALESCE(active, true)
FROM dblink('dbname=meatvo_db', 'SELECT * FROM coupons') 
AS old_coupons(id bigint, code text, discount_type text, discount_value numeric, min_order_value numeric, max_uses int, used_count int, active boolean);

-- 7. Migrate orders
INSERT INTO orders (id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at, updated_at)
SELECT 
  id, 
  customer_id, 
  status::text, 
  total_amount, 
  coupon_id, 
  address, 
  payment_mode::text, 
  created_at, 
  COALESCE(updated_at, created_at)
FROM dblink('dbname=meatvo_db', 'SELECT * FROM orders') 
AS old_orders(id bigint, customer_id bigint, status text, total_amount numeric, coupon_id bigint, address jsonb, payment_mode text, created_at timestamptz, updated_at timestamptz);

-- Backfill order numbers
UPDATE orders SET order_number = 'MVT' || TO_CHAR(created_at, 'YYYYMMDD') || LPAD(id::text, 6, '0')
WHERE order_number IS NULL;

-- Set subtotal (approximate)
UPDATE orders SET subtotal = total_amount WHERE subtotal IS NULL;

-- Link to addresses table
UPDATE orders o
SET address_id = a.id
FROM addresses a
WHERE o.customer_id = a.user_id 
  AND a.is_default = true
  AND o.address_id IS NULL;

-- 8. Migrate order_items
INSERT INTO order_items (id, order_id, product_id, quantity, price)
SELECT id, order_id, product_id, quantity, price
FROM dblink('dbname=meatvo_db', 'SELECT * FROM order_items') 
AS old_items(id bigint, order_id bigint, product_id bigint, quantity int, price numeric);

-- Backfill product snapshot
UPDATE order_items oi
SET 
  product_name = p.name,
  product_image = p.image_url,
  sku = p.sku,
  unit_price = oi.price,
  total_price = oi.quantity * oi.price
FROM products p
WHERE oi.product_id = p.id;

-- 9. Migrate delivery_partners
INSERT INTO delivery_partners (id, user_id, is_online, approved, current_lat, current_lng, vehicle_type, vehicle_number, licence_number, bank_details, earnings, updated_at)
SELECT 
  id, 
  user_id, 
  COALESCE(is_online, false), 
  COALESCE(approved, true), 
  current_lat, 
  current_lng, 
  vehicle_type, 
  vehicle_number, 
  licence_number, 
  bank_details, 
  COALESCE(earnings, 0), 
  COALESCE(updated_at, NOW())
FROM dblink('dbname=meatvo_db', 'SELECT * FROM delivery_partners') 
AS old_riders(id bigint, user_id bigint, is_online boolean, approved boolean, current_lat numeric, current_lng numeric, vehicle_type text, vehicle_number text, licence_number text, bank_details text, earnings numeric, updated_at timestamptz);

-- Set availability
UPDATE delivery_partners SET availability = CASE
  WHEN is_online THEN 'AVAILABLE'::rider_availability
  ELSE 'OFFLINE'::rider_availability
END;

-- Set location
UPDATE delivery_partners 
SET current_location = ST_SetSRID(ST_MakePoint(current_lng, current_lat), 4326)::geography
WHERE current_lat IS NOT NULL AND current_lng IS NOT NULL;

-- 10. Migrate order_assignments
INSERT INTO order_assignments (id, order_id, delivery_partner_id, assigned_at, status, updated_at)
SELECT id, order_id, delivery_partner_id, assigned_at, status::text, COALESCE(updated_at, assigned_at)
FROM dblink('dbname=meatvo_db', 'SELECT * FROM order_assignments') 
AS old_assignments(id bigint, order_id bigint, delivery_partner_id bigint, assigned_at timestamptz, status text, updated_at timestamptz);

-- 11. Migrate banners
INSERT INTO banners (id, image_url, active, sort_order)
SELECT id, image_url, COALESCE(active, true), COALESCE(sort_order, 0)
FROM dblink('dbname=meatvo_db', 'SELECT * FROM banners') 
AS old_banners(id bigint, image_url text, active boolean, sort_order int);

-- 12. Migrate OTP logs (last 7 days only)
INSERT INTO otp_logs (id, phone, otp, template_id, msg91_response, expires_at, verified, created_at)
SELECT id, phone, otp, template_id, msg91_response, expires_at, COALESCE(verified, false), created_at
FROM dblink('dbname=meatvo_db', 
  'SELECT * FROM otp_logs WHERE created_at > NOW() - INTERVAL ''7 days''') 
AS old_otps(id bigint, phone text, otp text, template_id text, msg91_response jsonb, expires_at timestamptz, verified boolean, created_at timestamptz);

-- 13. Migrate delivery_slots
INSERT INTO delivery_slots (id, name, start_time, end_time, slot_date, capacity, booked, is_active, created_at)
SELECT id, name, start_time, end_time, slot_date, capacity, booked, COALESCE(is_active, true), created_at
FROM dblink('dbname=meatvo_db', 'SELECT * FROM delivery_slots') 
AS old_slots(id bigint, name varchar, start_time time, end_time time, slot_date date, capacity int, booked int, is_active boolean, created_at timestamptz);

-- 14. Migrate app_settings
INSERT INTO app_settings (key, value, updated_at)
SELECT key, value, updated_at
FROM dblink('dbname=meatvo_db', 'SELECT * FROM app_settings') 
AS old_settings(key text, value jsonb, updated_at timestamptz);
```

### 4.3 Create New Tables
```sql
-- Create wallets for all users
INSERT INTO wallets (user_id, balance, locked_balance)
SELECT id, 0, 0
FROM users;

-- Generate referral codes for all users
INSERT INTO referral_codes (user_id, referrer_reward, referee_reward)
SELECT id, 50, 50
FROM users
WHERE role = 'customer';

-- Update sequences
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('categories_id_seq', (SELECT MAX(id) FROM categories));
SELECT setval('products_id_seq', (SELECT MAX(id) FROM products));
SELECT setval('orders_id_seq', (SELECT MAX(id) FROM orders));
SELECT setval('coupons_id_seq', (SELECT MAX(id) FROM coupons));
SELECT setval('delivery_partners_id_seq', (SELECT MAX(id) FROM delivery_partners));
```

### 4.4 Verify Data Integrity
```sql
-- Row count comparison
SELECT 'users' AS table_name, COUNT(*) AS new_count, 
  (SELECT COUNT(*) FROM dblink('dbname=meatvo_db', 'SELECT COUNT(*) FROM users') AS t(count bigint)) AS old_count
FROM users
UNION ALL
SELECT 'products', COUNT(*), 
  (SELECT COUNT(*) FROM dblink('dbname=meatvo_db', 'SELECT COUNT(*) FROM products') AS t(count bigint))
FROM products
UNION ALL
SELECT 'orders', COUNT(*), 
  (SELECT COUNT(*) FROM dblink('dbname=meatvo_db', 'SELECT COUNT(*) FROM orders') AS t(count bigint))
FROM orders;

-- Foreign key validation
SELECT 'Invalid customer_id in orders' AS check_name, COUNT(*)
FROM orders o
LEFT JOIN users u ON o.customer_id = u.id
WHERE u.id IS NULL
UNION ALL
SELECT 'Invalid product_id in order_items', COUNT(*)
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.id
WHERE p.id IS NULL
UNION ALL
SELECT 'Invalid user_id in addresses', COUNT(*)
FROM addresses a
LEFT JOIN users u ON a.user_id = u.id
WHERE u.id IS NULL;

-- Data consistency checks
SELECT 'Products without inventory' AS check_name, COUNT(*)
FROM products p
LEFT JOIN inventory i ON p.id = i.product_id
WHERE i.id IS NULL
UNION ALL
SELECT 'Users without wallets', COUNT(*)
FROM users u
LEFT JOIN wallets w ON u.id = w.user_id
WHERE w.id IS NULL;
```

---

## Step 5: Switch Over

### 5.1 Stop Application
```bash
# Stop backend
pm2 stop meatvo-backend

# Stop workers
pm2 stop meatvo-worker
```

### 5.2 Final Sync (Incremental)
```sql
-- Sync any new data created since migration started
-- (Run same INSERT queries with WHERE created_at > 'migration_start_time')
```

### 5.3 Switch Database
```bash
# Rename databases
psql -U postgres <<EOF
ALTER DATABASE meatvo_db RENAME TO meatvo_db_old;
ALTER DATABASE meatvo_db_new RENAME TO meatvo_db;
EOF
```

### 5.4 Update Application Config
```bash
# Update backend .env
# DATABASE_URL should point to meatvo_db (already does)

# No changes needed if database name remains same
```

### 5.5 Start Application
```bash
# Start backend
pm2 start meatvo-backend

# Verify health
curl http://localhost:8080/health
```

---

## Step 6: Post-Migration Validation

### 6.1 Smoke Tests
```bash
# Test API endpoints
curl http://localhost:8080/api/products
curl http://localhost:8080/api/categories
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/orders
```

### 6.2 Database Health
```sql
-- Analyze statistics
ANALYZE;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY tablename, indexname;

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

### 6.3 Monitor Logs
```bash
# Backend logs
pm2 logs meatvo-backend --lines 100

# PostgreSQL logs
tail -f /var/log/postgresql/postgresql-14-main.log
```

---

## Step 7: Rollback Plan

If migration fails:

```bash
# Stop application
pm2 stop all

# Restore old database
psql -U postgres <<EOF
ALTER DATABASE meatvo_db RENAME TO meatvo_db_failed;
ALTER DATABASE meatvo_db_old RENAME TO meatvo_db;
EOF

# Start application
pm2 start all

# Verify rollback
curl http://localhost:8080/health
```

---

## Common Issues & Solutions

### Issue 1: Foreign Key Violations
```sql
-- Find orphaned records
SELECT 'orders with invalid customer_id', COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.customer_id);

-- Fix: Delete or update
DELETE FROM orders WHERE customer_id NOT IN (SELECT id FROM users);
```

### Issue 2: Duplicate Slugs
```sql
-- Find duplicates
SELECT slug, COUNT(*) 
FROM products 
GROUP BY slug 
HAVING COUNT(*) > 1;

-- Fix: Append ID
UPDATE products 
SET slug = slug || '-' || id 
WHERE id IN (
  SELECT id FROM products p1
  WHERE EXISTS (
    SELECT 1 FROM products p2 
    WHERE p1.slug = p2.slug AND p1.id > p2.id
  )
);
```

### Issue 3: Partition Key Mismatch
```sql
-- Check partition boundaries
SELECT 
  parent.relname AS parent_table,
  child.relname AS partition_name,
  pg_get_expr(child.relpartbound, child.oid) AS partition_range
FROM pg_class parent
JOIN pg_inherits ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
WHERE parent.relname IN ('orders', 'payments', 'notifications')
ORDER BY parent_table, partition_name;
```

---

## Performance Tuning Post-Migration

```sql
-- Rebuild indexes
REINDEX DATABASE meatvo_db;

-- Update statistics
ANALYZE VERBOSE;

-- Vacuum
VACUUM ANALYZE;
```

---

## Monitoring First 24 Hours

- [ ] API response times
- [ ] Database connection pool usage
- [ ] Error rates
- [ ] User-reported issues
- [ ] Database size growth
- [ ] Query performance (pg_stat_statements)

---

## Document Version

- **Version:** 1.0
- **Date:** 2026-06-13
- **Tested On:** PostgreSQL 14.x

---

**End of Migration Guide**
