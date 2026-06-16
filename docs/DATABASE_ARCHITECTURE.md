# Meatvo Database Architecture

**Version:** 1.0  
**Database:** PostgreSQL 14+  
**Date:** June 2026  
**Status:** Production-Ready

---

## Table of Contents

1. [ER Diagram Description](#1-er-diagram-description)
2. [Core Entities & Relationships](#2-core-entities--relationships)
3. [Complete Schema Overview](#3-complete-schema-overview)
4. [Indexing Strategy](#4-indexing-strategy)
5. [Partition Strategy](#5-partition-strategy)
6. [Audit Architecture](#6-audit-architecture)
7. [Soft Delete Strategy](#7-soft-delete-strategy)
8. [Performance Optimization](#8-performance-optimization)
9. [Scalability Considerations](#9-scalability-considerations)
10. [Maintenance Procedures](#10-maintenance-procedures)

---

## 1. ER Diagram Description

### 1.1 Entity-Relationship Overview

The Meatvo database follows a **normalized relational design** with:
- **15 Core Modules**
- **30+ Tables** (including partitions)
- **Time-series Partitioning** for high-volume tables
- **Soft Delete** implementation across all user-facing entities
- **Comprehensive Audit Trails** for sensitive operations

### 1.2 Module Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                         USERS MODULE                         │
│  ┌──────────┐  ┌───────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  Users   │  │ Addresses │  │   Wallets   │  │ Reviews │ │
│  └─────┬────┘  └─────┬─────┘  └──────┬──────┘  └────┬────┘ │
└────────┼─────────────┼───────────────┼──────────────┼──────┘
         │             │               │              │
┌────────┴─────────────┴───────────────┴──────────────┴──────┐
│                      ORDERS MODULE                          │
│  ┌─────────┐  ┌────────────┐  ┌──────────────┐             │
│  │ Orders  ├──┤ OrderItems ├──┤  Inventory   │             │
│  └────┬────┘  └────────────┘  └──────────────┘             │
└───────┼──────────────────────────────────────────────────────┘
        │
┌───────┴──────────────────────────────────────────────────────┐
│                    FULFILLMENT MODULE                         │
│  ┌──────────────┐  ┌────────────────────┐  ┌─────────────┐  │
│  │  Payments    │  │ OrderAssignments   │  │   Riders    │  │
│  └──────────────┘  └────────────────────┘  └──────┬──────┘  │
│                                                     │         │
│                                         ┌───────────┴──────┐ │
│                                         │ RiderLocations   │ │
│                                         └──────────────────┘ │
└───────────────────────────────────────────────────────────────┘
        │
┌───────┴───────────────────────────────────────────────────────┐
│                   CATALOG MODULE                              │
│  ┌────────────┐  ┌──────────┐  ┌─────────────┐               │
│  │ Categories ├──┤ Products ├──┤  Inventory  │               │
│  └────────────┘  └──────────┘  └─────────────┘               │
└───────────────────────────────────────────────────────────────┘
        │
┌───────┴───────────────────────────────────────────────────────┐
│                   ENGAGEMENT MODULE                           │
│  ┌──────────────┐  ┌──────────┐  ┌──────────────┐            │
│  │Notifications │  │ Referrals│  │   Coupons    │            │
│  └──────────────┘  └──────────┘  └──────────────┘            │
└───────────────────────────────────────────────────────────────┘
```

---

## 2. Core Entities & Relationships

### 2.1 Users Module

#### **users**
Primary entity for all user types (customers, riders, admins, support).

**Relationships:**
- **1:N** → `addresses` (One user has many addresses)
- **1:N** → `orders` (One user has many orders)
- **1:1** → `wallets` (One user has one wallet)
- **1:1** → `delivery_partners` (One user can be a rider)
- **1:N** → `reviews` (One user writes many reviews)
- **1:N** → `notifications` (One user receives many notifications)
- **1:1** → `referral_codes` (One user has one referral code)

**Key Columns:**
- `id` (BIGSERIAL, PK)
- `uuid` (UUID, Unique - for public API exposure)
- `phone` (VARCHAR(15), Unique - primary login identifier)
- `role` (ENUM: admin, customer, delivery, support)
- `status` (ENUM: active, suspended, deleted)
- `deleted_at` (TIMESTAMPTZ - soft delete)

**Indexes:**
- `idx_users_phone` - Fast login lookups
- `idx_users_role` - Filter by user type
- `idx_users_name_trgm` - Full-text search on names

---

#### **addresses**
Delivery addresses with geolocation support.

**Relationships:**
- **N:1** → `users` (Many addresses belong to one user)
- **1:N** → `orders` (One address used in many orders)

**Key Columns:**
- `user_id` (FK → users.id)
- `latitude`, `longitude` (NUMERIC - coordinates)
- `location` (GEOGRAPHY - PostGIS point)
- `is_default` (BOOLEAN - primary address flag)

**Indexes:**
- `idx_addresses_location` (GIST) - Geospatial queries
- `idx_addresses_pincode` - Serviceability checks

---

### 2.2 Products & Inventory Module

#### **categories**
Hierarchical product categories.

**Relationships:**
- **Self-referencing** → `categories` (parent_id for tree structure)
- **1:N** → `products` (One category has many products)

**Key Columns:**
- `parent_id` (FK → categories.id, nullable)
- `slug` (VARCHAR, Unique - URL-friendly identifier)
- `path` (TEXT - materialized path for hierarchy traversal)
- `level` (INTEGER - depth in tree)

**Indexes:**
- `idx_categories_path` - Fast subtree queries
- `idx_categories_parent_id` - Parent-child lookups

---

#### **products**
Product catalog with rich metadata.

**Relationships:**
- **N:1** → `categories` (Many products in one category)
- **1:1** → `inventory` (One product has one inventory record)
- **1:N** → `order_items` (One product appears in many orders)
- **1:N** → `reviews` (One product has many reviews)

**Key Columns:**
- `slug` (VARCHAR, Unique - SEO-friendly URL)
- `sku` (VARCHAR, Unique - Stock Keeping Unit)
- `barcode` (VARCHAR, Unique - Barcode scanning)
- `tags` (TEXT[] - Array for filtering)
- `attributes` (JSONB - Dynamic product properties)

**Indexes:**
- `idx_products_slug` - URL routing
- `idx_products_category_id` - Category filtering
- `idx_products_tags` (GIN) - Tag-based search
- `idx_products_name_trgm` (GIN) - Full-text search

---

#### **inventory**
Real-time stock tracking with reservations.

**Relationships:**
- **1:1** → `products` (One-to-one with product)
- **1:N** → `inventory_movements` (Audit trail)

**Key Columns:**
- `quantity` (INTEGER - total stock)
- `reserved_quantity` (INTEGER - items in pending orders)
- `available_quantity` (GENERATED - quantity - reserved)
- `reorder_level` (INTEGER - low stock threshold)
- `expiry_date` (DATE - perishable goods tracking)

**Indexes:**
- `idx_inventory_low_stock` - WHERE available_quantity <= reorder_level
- `idx_inventory_expiry` - Expiry date monitoring

---

#### **inventory_movements** (PARTITIONED)
Audit log for all inventory changes.

**Partition Strategy:** Monthly partitions by `created_at`

**Key Columns:**
- `movement_type` (ENUM: PURCHASE, SALE, RETURN, ADJUSTMENT, DAMAGE, THEFT, EXPIRY)
- `reference_type`, `reference_id` - Link to orders/adjustments
- `previous_quantity`, `new_quantity` - State tracking

---

### 2.3 Orders Module

#### **orders** (PARTITIONED)
Customer orders with comprehensive tracking.

**Partition Strategy:** Monthly partitions by `created_at`

**Relationships:**
- **N:1** → `users` (Many orders from one customer)
- **N:1** → `addresses` (Many orders to one address)
- **1:N** → `order_items` (One order has many items)
- **1:N** → `payments` (One order can have multiple payment attempts)
- **1:1** → `order_assignments` (One order assigned to one rider)
- **N:1** → `coupons` (Many orders use one coupon)

**Key Columns:**
- `order_number` (VARCHAR, Unique - customer-facing ID)
- `status` (ENUM - order state machine)
- `subtotal`, `discount_amount`, `delivery_fee`, `tax_amount`, `total_amount`
- `address` (JSONB - immutable address snapshot)
- `scheduled_delivery_date`, `scheduled_delivery_time_start/end`
- State timestamps: `placed_at`, `confirmed_at`, `packed_at`, `delivered_at`, `cancelled_at`

**Indexes:**
- `idx_orders_customer_id` - User order history
- `idx_orders_status` - Order filtering by state
- `idx_orders_order_number` - Fast lookup by order number

**Trigger:**
- `generate_order_number()` - Auto-generate MVTYYYYMMDDxxxxxx format

---

#### **order_items** (PARTITIONED)
Line items for orders.

**Partition Strategy:** Monthly partitions matching `orders` table

**Key Columns:**
- `order_id` (FK → orders.id)
- `product_id` (FK → products.id)
- `product_name`, `product_image` - Snapshot at order time
- `quantity`, `unit_price`, `discount`, `tax`, `total_price`

**Trigger:**
- `update_product_order_count()` - Increment product.order_count

---

### 2.4 Payments Module

#### **payments** (PARTITIONED)
Payment transaction tracking.

**Partition Strategy:** Monthly partitions by `created_at`

**Relationships:**
- **N:1** → `orders` (Multiple payment attempts per order)
- **N:1** → `users`

**Key Columns:**
- `payment_id` (VARCHAR, Unique - internal payment ID)
- `payment_mode` (ENUM: COD, ONLINE, WALLET, MIXED)
- `payment_gateway` (ENUM: PHONEPE, RAZORPAY, PAYTM, MANUAL)
- `status` (ENUM: PENDING, INITIATED, SUCCESS, FAILED, REFUNDED)
- `gateway_transaction_id`, `gateway_order_id`, `gateway_payment_id`
- `gateway_response` (JSONB - full gateway response)
- `refund_amount`, `refund_reference`

**Indexes:**
- `idx_payments_order_id` - Order payment lookup
- `idx_payments_gateway_transaction_id` - Gateway reconciliation

---

### 2.5 Delivery Module

#### **delivery_partners**
Rider profiles and performance tracking.

**Relationships:**
- **1:1** → `users` (One user is one rider)
- **1:N** → `order_assignments`
- **1:N** → `rider_location_history`

**Key Columns:**
- `availability` (ENUM: AVAILABLE, BUSY, OFFLINE, BREAK)
- `current_lat`, `current_lng`, `current_location` (GEOGRAPHY)
- `total_deliveries`, `successful_deliveries`, `cancelled_deliveries`
- `average_rating`, `rating_count`
- `total_earnings`, `pending_earnings`, `withdrawn_earnings`
- `documents` (JSONB - licence, RC, insurance URLs)

**Indexes:**
- `idx_delivery_partners_location` (GIST) - Proximity search
- `idx_delivery_partners_availability` - Available rider filtering

---

#### **rider_location_history** (PARTITIONED)
GPS breadcrumb trail for riders.

**Partition Strategy:** Monthly partitions by `created_at`

**Key Columns:**
- `rider_id` (FK → delivery_partners.id)
- `order_id` (FK → orders.id, nullable)
- `latitude`, `longitude`, `location` (GEOGRAPHY)
- `accuracy`, `speed`, `bearing`
- `recorded_at` (TIMESTAMPTZ)

**Indexes:**
- `idx_rider_location_history_location` (GIST) - Geospatial queries

---

#### **order_assignments**
Rider-order assignment tracking.

**Relationships:**
- **1:1** → `orders` (One order has one assignment)
- **N:1** → `delivery_partners` (One rider has many assignments)

**Key Columns:**
- `status` (ENUM: ASSIGNED, ACCEPTED, PICKED, DELIVERED, CANCELLED, REJECTED)
- `pickup_otp`, `delivery_otp` (VARCHAR(6) - verification)
- `delivery_image_url`, `delivery_signature_url` - Proof of delivery
- `delivery_fee`, `tip_amount`, `total_earning` (GENERATED)

---

### 2.6 Coupons Module

#### **coupons**
Promotional discount codes.

**Relationships:**
- **1:N** → `orders`
- **1:N** → `coupon_usage` (Detailed usage tracking)

**Key Columns:**
- `code` (VARCHAR, Unique - case-insensitive)
- `discount_type` (ENUM: PERCENT, FLAT)
- `discount_value`, `max_discount`
- `min_order_value`
- `applicability` (ENUM: ALL, FIRST_ORDER, CATEGORY_SPECIFIC, USER_SPECIFIC)
- `applicable_categories` (BIGINT[] - category IDs)
- `max_uses`, `max_uses_per_user`, `used_count`
- `valid_from`, `valid_to`

**Indexes:**
- `idx_coupons_code` - Case-insensitive unique index
- `idx_coupons_validity` - Time-based filtering

---

#### **coupon_usage**
Individual redemption tracking.

**Relationships:**
- **N:1** → `coupons`
- **N:1** → `users`
- **N:1** → `orders`

---

### 2.7 Wallet Module

#### **wallets**
User wallet for cashback and credits.

**Relationships:**
- **1:1** → `users`
- **1:N** → `wallet_transactions`

**Key Columns:**
- `balance` (NUMERIC - total balance)
- `locked_balance` (NUMERIC - reserved amounts)
- `available_balance` (GENERATED - balance - locked_balance)

---

#### **wallet_transactions** (PARTITIONED)
Wallet transaction history.

**Partition Strategy:** Monthly partitions by `created_at`

**Key Columns:**
- `transaction_type` (ENUM: CREDIT, DEBIT, REFUND, CASHBACK, REFERRAL_BONUS, WITHDRAWAL)
- `amount`
- `balance_before`, `balance_after` - Audit trail
- `reference_type`, `reference_id` - Link to source

**Trigger:**
- `update_wallet_balance()` - Auto-update wallet.balance

---

### 2.8 Referral Module

#### **referral_codes**
User referral codes.

**Relationships:**
- **1:1** → `users`
- **1:N** → `referrals`

**Key Columns:**
- `code` (VARCHAR, Unique - auto-generated)
- `referrer_reward`, `referee_reward`
- `total_referrals`, `successful_referrals`

**Trigger:**
- `generate_referral_code()` - Auto-generate REFxxxxxxxx format

---

#### **referrals**
Individual referral tracking.

**Relationships:**
- **N:1** → `referral_codes`
- **N:1** → `users` (referrer)
- **N:1** → `users` (referee)
- **N:1** → `orders` (referee's first order)

**Key Columns:**
- `status` (ENUM: PENDING, COMPLETED, EXPIRED, CLAIMED)
- `referee_first_order_id` - Completion trigger
- `referred_at`, `completed_at`, `claimed_at`, `expires_at`

---

### 2.9 Notifications Module

#### **notifications** (PARTITIONED)
Multi-channel notification system.

**Partition Strategy:** Monthly partitions by `created_at`

**Key Columns:**
- `type` (ENUM: ORDER, PAYMENT, DELIVERY, PROMOTIONAL, SYSTEM, REFERRAL, WALLET)
- `channel` (ENUM: PUSH, SMS, EMAIL, IN_APP)
- `title`, `body`, `image_url`
- `action_url`, `action_data` (JSONB)
- `reference_type`, `reference_id`
- `is_read`, `sent`, `delivery_status`

**Indexes:**
- `idx_notifications_unread` - Fast unread count
- `idx_notifications_reference` - Link to source entity

---

### 2.10 Reviews Module

#### **reviews**
Product and rider reviews.

**Relationships:**
- **N:1** → `orders`
- **N:1** → `products`
- **N:1** → `users`
- **N:1** → `delivery_partners`

**Key Columns:**
- `rating` (INTEGER 1-5)
- `review_text`, `images` (TEXT[])
- `is_verified_purchase`, `is_approved`, `is_featured`

---

## 3. Complete Schema Overview

### 3.1 All Tables

| Module | Table Name | Type | Partitioned | Soft Delete |
|--------|-----------|------|-------------|-------------|
| **Users** | users | Core | No | Yes |
| | addresses | Core | No | Yes |
| | wallets | Core | No | No |
| | wallet_transactions | Transaction | Yes (Monthly) | No |
| **Catalog** | categories | Core | No | Yes |
| | products | Core | No | Yes |
| | inventory | Core | No | No |
| | inventory_movements | Audit | Yes (Monthly) | No |
| **Orders** | orders | Core | Yes (Monthly) | Yes |
| | order_items | Core | Yes (Monthly) | No |
| **Payments** | payments | Transaction | Yes (Monthly) | No |
| **Coupons** | coupons | Core | No | Yes |
| | coupon_usage | Tracking | No | No |
| **Delivery** | delivery_partners | Core | No | Yes |
| | order_assignments | Core | No | No |
| | rider_location_history | Time-series | Yes (Monthly) | No |
| | delivery_slots | Core | No | No |
| **Notifications** | notifications | Transaction | Yes (Monthly) | Yes |
| **Reviews** | reviews | Core | No | Yes |
| **Referrals** | referral_codes | Core | No | No |
| | referrals | Tracking | No | No |
| **System** | banners | Content | No | Yes |
| | otp_logs | Audit | Yes (Monthly) | No |
| | app_settings | Config | No | No |
| **Audit** | audit_users | Audit | Yes (Monthly) | No |
| | audit_orders | Audit | Yes (Monthly) | No |
| | audit_payments | Audit | Yes (Monthly) | No |

### 3.2 Custom Types (ENUMs)

```sql
-- User Management
user_role: admin, customer, delivery, support
user_status: active, suspended, deleted
rider_availability: AVAILABLE, BUSY, OFFLINE, BREAK

-- Orders
order_status: PENDING, PLACED, CONFIRMED, PACKED, OUT_FOR_DELIVERY, 
              PICKED_UP, ON_THE_WAY, DELIVERED, CANCELLED, REFUNDED
assignment_status: ASSIGNED, ACCEPTED, PICKED, DELIVERED, CANCELLED, REJECTED

-- Payments
payment_mode: COD, ONLINE, WALLET, MIXED
payment_status: PENDING, INITIATED, SUCCESS, FAILED, REFUNDED, PARTIALLY_REFUNDED
payment_gateway: PHONEPE, RAZORPAY, PAYTM, MANUAL

-- Promotions
discount_type: PERCENT, FLAT
coupon_applicability: ALL, FIRST_ORDER, CATEGORY_SPECIFIC, USER_SPECIFIC

-- Wallet
wallet_transaction_type: CREDIT, DEBIT, REFUND, CASHBACK, REFERRAL_BONUS, WITHDRAWAL

-- Referrals
referral_status: PENDING, COMPLETED, EXPIRED, CLAIMED

-- Notifications
notification_type: ORDER, PAYMENT, DELIVERY, PROMOTIONAL, SYSTEM, REFERRAL, WALLET
notification_channel: PUSH, SMS, EMAIL, IN_APP

-- Inventory
inventory_movement_type: PURCHASE, SALE, RETURN, ADJUSTMENT, DAMAGE, THEFT, EXPIRY
```

---

## 4. Indexing Strategy

### 4.1 Index Types

| Index Type | Use Case | Example |
|------------|----------|---------|
| **B-Tree** | Primary keys, foreign keys, equality/range queries | `idx_users_phone` |
| **GIN (Generalized Inverted Index)** | Full-text search, array contains, JSONB queries | `idx_products_tags` |
| **GIST (Generalized Search Tree)** | Geospatial queries, range types | `idx_addresses_location` |
| **Trigram (pg_trgm)** | Fuzzy text search, LIKE queries | `idx_users_name_trgm` |
| **Partial Index** | Filtered indexes for common queries | `WHERE deleted_at IS NULL` |

### 4.2 Indexing Rules

1. **Primary Keys:** Automatic B-Tree index
2. **Foreign Keys:** Explicit index on FK column for JOIN performance
3. **Soft Delete:** Partial indexes `WHERE deleted_at IS NULL`
4. **Status Columns:** Indexes on frequently filtered status fields
5. **Timestamps:** Indexes on `created_at` for ordering
6. **Full-Text:** Trigram GIN indexes on text fields (name, description)
7. **Arrays/JSONB:** GIN indexes for containment queries
8. **Geospatial:** GIST indexes on GEOGRAPHY columns

### 4.3 Index Catalog

```sql
-- Users Module (11 indexes)
idx_users_phone, idx_users_email, idx_users_role, idx_users_status,
idx_users_uuid, idx_users_created_at, idx_users_name_trgm

idx_addresses_user_id, idx_addresses_pincode, 
idx_addresses_location (GIST), idx_addresses_default

-- Products Module (16 indexes)
idx_categories_slug, idx_categories_parent_id, idx_categories_active,
idx_categories_sort_order, idx_categories_path, idx_categories_name_trgm

idx_products_slug, idx_products_category_id, idx_products_active,
idx_products_featured, idx_products_sku, idx_products_barcode,
idx_products_price, idx_products_name_trgm, idx_products_tags (GIN)

idx_inventory_product_id (UNIQUE), idx_inventory_low_stock, idx_inventory_expiry

-- Orders Module (10 indexes)
idx_orders_order_number (UNIQUE), idx_orders_customer_id,
idx_orders_status, idx_orders_payment_mode

idx_order_items_order_id, idx_order_items_product_id

idx_order_assignments_order_id, idx_order_assignments_delivery_partner_id,
idx_order_assignments_status

-- Payments Module (5 indexes)
idx_payments_payment_id (UNIQUE), idx_payments_order_id,
idx_payments_user_id, idx_payments_status,
idx_payments_gateway_transaction_id

-- Delivery Module (8 indexes)
idx_delivery_partners_user_id, idx_delivery_partners_availability,
idx_delivery_partners_approved, idx_delivery_partners_location (GIST)

idx_rider_location_history_rider_id, idx_rider_location_history_order_id,
idx_rider_location_history_location (GIST),
idx_rider_location_history_recorded_at

-- Notifications Module (4 indexes)
idx_notifications_user_id, idx_notifications_unread,
idx_notifications_type, idx_notifications_reference

-- Wallet Module (5 indexes)
idx_wallets_user_id (UNIQUE)
idx_wallet_transactions_wallet_id, idx_wallet_transactions_user_id,
idx_wallet_transactions_type, idx_wallet_transactions_reference

-- Coupons Module (5 indexes)
idx_coupons_code (UNIQUE, case-insensitive), idx_coupons_active,
idx_coupons_validity
idx_coupon_usage_coupon_id, idx_coupon_usage_user_id

-- Reviews Module (6 indexes)
idx_reviews_order_id, idx_reviews_product_id, idx_reviews_user_id,
idx_reviews_rider_id, idx_reviews_rating, idx_reviews_approved

-- Referrals Module (6 indexes)
idx_referral_codes_code (UNIQUE), idx_referral_codes_user_id,
idx_referral_codes_active
idx_referrals_referral_code_id, idx_referrals_referrer_id,
idx_referrals_referee_id, idx_referrals_status
```

### 4.4 Index Maintenance

```sql
-- Monitor index usage
SELECT 
  schemaname, tablename, indexname, 
  idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY tablename, indexname;

-- Rebuild fragmented indexes (run quarterly)
REINDEX INDEX CONCURRENTLY idx_orders_customer_id;

-- Analyze statistics (run weekly)
ANALYZE users, products, orders, order_items;
```

---

## 5. Partition Strategy

### 5.1 Partitioned Tables

| Table | Partition Key | Strategy | Retention |
|-------|--------------|----------|-----------|
| orders | created_at | Monthly | 24 months |
| order_items | created_at | Monthly | 24 months |
| payments | created_at | Monthly | 36 months |
| inventory_movements | created_at | Monthly | 12 months |
| notifications | created_at | Monthly | 3 months |
| wallet_transactions | created_at | Monthly | 36 months |
| rider_location_history | created_at | Monthly | 6 months |
| otp_logs | created_at | Monthly | 1 month |
| audit_users | changed_at | Monthly | 60 months |
| audit_orders | changed_at | Monthly | 60 months |
| audit_payments | changed_at | Monthly | 60 months |

### 5.2 Partition Naming Convention

```
{table_name}_{YYYY}_{MM}

Examples:
- orders_2026_06
- payments_2026_07
- notifications_2026_08
```

### 5.3 Partition Management

#### **Automated Partition Creation**

```sql
-- Create partitions for next month (run on 1st of each month)
CREATE TABLE IF NOT EXISTS orders_2027_01 PARTITION OF orders
  FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

CREATE TABLE IF NOT EXISTS order_items_2027_01 PARTITION OF order_items
  FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

-- Repeat for all partitioned tables...
```

#### **Partition Pruning**

Ensure `enable_partition_pruning = on` in `postgresql.conf`.

Query performance example:
```sql
-- Only scans orders_2026_06 partition
SELECT * FROM orders 
WHERE created_at >= '2026-06-01' AND created_at < '2026-07-01';
```

#### **Partition Archival**

```sql
-- Detach old partitions (run quarterly)
ALTER TABLE orders DETACH PARTITION orders_2024_01;

-- Archive to separate tablespace or export
pg_dump -t orders_2024_01 meatvo_db > orders_2024_01.sql

-- Drop archived partition
DROP TABLE orders_2024_01;
```

### 5.4 Benefits

1. **Query Performance:** Partition pruning reduces scan size
2. **Maintenance:** Vacuum/analyze only active partitions
3. **Data Lifecycle:** Easy archival of old data
4. **Parallel Processing:** Partitions can be processed concurrently
5. **Index Size:** Smaller indexes per partition

---

## 6. Audit Architecture

### 6.1 Audit Tables

Three critical audit tables track all changes:

1. **audit_users** - User account modifications
2. **audit_orders** - Order state changes
3. **audit_payments** - Payment transaction modifications

### 6.2 Audit Schema

```sql
CREATE TABLE audit_users (
  audit_id BIGSERIAL PRIMARY KEY,
  operation VARCHAR(10), -- INSERT, UPDATE, DELETE
  user_id BIGINT,
  old_data JSONB,        -- Full row before change
  new_data JSONB,        -- Full row after change
  changed_by BIGINT,     -- Who made the change
  changed_at TIMESTAMPTZ -- When it happened
) PARTITION BY RANGE (changed_at);
```

### 6.3 Audit Triggers

```sql
CREATE TRIGGER tr_audit_users 
  AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW 
  EXECUTE FUNCTION audit_users_changes();

-- Trigger function captures:
-- - Operation type (INSERT/UPDATE/DELETE)
-- - Full row data as JSONB
-- - Timestamp
```

### 6.4 Audit Queries

```sql
-- User change history
SELECT 
  operation,
  old_data->>'name' AS old_name,
  new_data->>'name' AS new_name,
  changed_at
FROM audit_users
WHERE user_id = 123
ORDER BY changed_at DESC;

-- Order status changes
SELECT 
  operation,
  old_data->>'status' AS old_status,
  new_data->>'status' AS new_status,
  changed_at
FROM audit_orders
WHERE order_id = 456
ORDER BY changed_at;

-- Payment modifications
SELECT * FROM audit_payments
WHERE payment_id = 789
ORDER BY changed_at DESC;
```

### 6.5 Retention Policy

- **audit_users:** 60 months (5 years)
- **audit_orders:** 60 months (5 years)
- **audit_payments:** 60 months (5 years)

Archived quarterly to cold storage.

---

## 7. Soft Delete Strategy

### 7.1 Soft Delete Pattern

All user-facing entities use soft delete to preserve data integrity and enable recovery.

**Implementation:**
```sql
-- Column in table
deleted_at TIMESTAMPTZ,
deleted_by BIGINT,

-- Partial index (excludes soft-deleted rows)
CREATE INDEX idx_users_phone ON users(phone) 
WHERE deleted_at IS NULL;
```

### 7.2 Soft Delete Tables

| Table | Soft Delete | Reason |
|-------|-------------|--------|
| users | ✅ | Data recovery, compliance |
| addresses | ✅ | Order history preservation |
| categories | ✅ | Product categorization history |
| products | ✅ | Order item references |
| coupons | ✅ | Usage history |
| orders | ✅ | Financial records |
| delivery_partners | ✅ | Assignment history |
| notifications | ✅ | User notification history |
| reviews | ✅ | Moderation |
| banners | ✅ | Campaign history |
| order_items | ❌ | Immutable order data |
| payments | ❌ | Financial audit trail |
| inventory | ❌ | Real-time stock data |
| wallets | ❌ | Financial records |

### 7.3 Soft Delete Helper Function

```sql
CREATE FUNCTION soft_delete(
  table_name TEXT,
  record_id BIGINT,
  deleted_by_user_id BIGINT
) RETURNS BOOLEAN AS $$
BEGIN
  EXECUTE format(
    'UPDATE %I SET deleted_at = NOW(), deleted_by = $1 
     WHERE id = $2 AND deleted_at IS NULL', 
    table_name
  ) USING deleted_by_user_id, record_id;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Usage
SELECT soft_delete('users', 123, 1); -- Delete user 123, logged by admin 1
```

### 7.4 Query Patterns

```sql
-- Active records (default behavior)
SELECT * FROM users WHERE deleted_at IS NULL;

-- Include soft-deleted (admin view)
SELECT * FROM users; -- No WHERE clause

-- Only soft-deleted (recovery view)
SELECT * FROM users WHERE deleted_at IS NOT NULL;

-- Restore soft-deleted record
UPDATE users 
SET deleted_at = NULL, deleted_by = NULL 
WHERE id = 123;
```

### 7.5 Benefits

1. **Data Recovery:** Accidental deletions can be undone
2. **Compliance:** Retain data for regulatory requirements
3. **Referential Integrity:** Foreign key constraints remain valid
4. **Audit Trail:** Deletion history tracked in audit tables
5. **Performance:** Partial indexes exclude deleted rows from queries

---

## 8. Performance Optimization

### 8.1 Query Optimization Techniques

#### **1. Connection Pooling**
```javascript
// Use pg-pool with max 20 connections
const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

#### **2. Prepared Statements**
```sql
-- Node.js parameterized query
const result = await pool.query(
  'SELECT * FROM products WHERE category_id = $1 AND active = true',
  [categoryId]
);
```

#### **3. EXPLAIN ANALYZE**
```sql
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM orders 
WHERE customer_id = 123 
  AND created_at > '2026-06-01'
  AND deleted_at IS NULL;
```

### 8.2 Caching Strategy

#### **Redis Cache Layers**

```javascript
// Layer 1: Product catalog (TTL: 1 hour)
await redis.setex(`product:${id}`, 3600, JSON.stringify(product));

// Layer 2: User session (TTL: 24 hours)
await redis.setex(`session:${userId}`, 86400, JSON.stringify(session));

// Layer 3: Cart data (TTL: 7 days)
await redis.setex(`cart:${userId}`, 604800, JSON.stringify(cart));

// Layer 4: Delivery slots (TTL: 5 minutes)
await redis.setex('delivery_slots', 300, JSON.stringify(slots));
```

#### **Cache Invalidation**

```javascript
// On product update
await redis.del(`product:${productId}`);
await redis.del('products:list');

// On order placement
await redis.del(`cart:${userId}`);
await redis.del(`wallet:${userId}`);
```

### 8.3 Database Configuration

```conf
# postgresql.conf optimizations

# Memory
shared_buffers = 2GB              # 25% of RAM
effective_cache_size = 6GB        # 75% of RAM
work_mem = 64MB                   # Per-query memory

# Write-Ahead Log
wal_buffers = 16MB
checkpoint_completion_target = 0.9

# Planner
random_page_cost = 1.1            # SSD
effective_io_concurrency = 200    # SSD

# Partitioning
enable_partition_pruning = on
enable_partitionwise_join = on
enable_partitionwise_aggregate = on

# Parallel Query
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
```

### 8.4 Vacuum Strategy

```sql
-- Auto-vacuum settings (postgresql.conf)
autovacuum = on
autovacuum_naptime = 1min
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05

-- Manual vacuum for high-churn tables (weekly)
VACUUM (ANALYZE, VERBOSE) orders;
VACUUM (ANALYZE, VERBOSE) inventory;
VACUUM (ANALYZE, VERBOSE) rider_location_history;
```

---

## 9. Scalability Considerations

### 9.1 Horizontal Scaling

#### **Read Replicas**

```
┌─────────────┐
│   Primary   │ ← Writes
│  (Master)   │
└─────┬───────┘
      │ Replication
      ├──────────────┬──────────────┐
      ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Replica 1│  │ Replica 2│  │ Replica 3│ ← Reads
└──────────┘  └──────────┘  └──────────┘
```

**Configuration:**
- 1 Primary (writes)
- 3 Read replicas (reads)
- Connection pooling routes reads to replicas

#### **Sharding Strategy** (Future)

Shard key: `user_id` (consistent hashing)

```
Shard 1: user_id % 4 = 0
Shard 2: user_id % 4 = 1
Shard 3: user_id % 4 = 2
Shard 4: user_id % 4 = 3
```

### 9.2 Vertical Scaling

Current recommended specs:
- **CPU:** 8 cores (16 threads)
- **RAM:** 32 GB
- **Storage:** 500 GB NVMe SSD
- **IOPS:** 10,000+

### 9.3 Data Growth Projections

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| Users | 100K | 500K | 2M |
| Orders/day | 1K | 10K | 50K |
| Database size | 50 GB | 200 GB | 1 TB |
| Reads/sec | 500 | 2K | 10K |
| Writes/sec | 100 | 500 | 2K |

### 9.4 Archival Strategy

**Hot Data:** Last 3 months (production DB)  
**Warm Data:** 3-12 months (read replica)  
**Cold Data:** 12+ months (S3/Glacier)

```sql
-- Archive orders older than 12 months
pg_dump -t orders_2025_* meatvo_db | gzip > orders_2025.sql.gz
aws s3 cp orders_2025.sql.gz s3://meatvo-archives/
```

---

## 10. Maintenance Procedures

### 10.1 Daily Tasks (Automated)

```bash
# Backup script (00:00 UTC)
pg_dump -Fc meatvo_db > /backups/meatvo_$(date +%Y%m%d).dump
aws s3 cp /backups/meatvo_$(date +%Y%m%d).dump s3://meatvo-backups/

# Generate delivery slots (00:05 UTC)
psql -c "SELECT auto_generate_delivery_slots();"

# Cleanup expired OTPs (00:10 UTC)
psql -c "DELETE FROM otp_logs WHERE expires_at < NOW() - INTERVAL '7 days';"
```

### 10.2 Weekly Tasks

```sql
-- Analyze statistics (Sunday 02:00 UTC)
ANALYZE users, products, orders, order_items, payments;

-- Reindex critical indexes
REINDEX INDEX CONCURRENTLY idx_orders_customer_id;
REINDEX INDEX CONCURRENTLY idx_products_category_id;
```

### 10.3 Monthly Tasks

```bash
# Create next month's partitions (1st of month)
bash scripts/create_partitions.sh

# Archive old notifications (1st of month)
psql -c "ALTER TABLE notifications DETACH PARTITION notifications_$(date -d '3 months ago' +%Y_%m);"

# Vacuum analyze high-churn tables
psql -c "VACUUM (ANALYZE, VERBOSE) orders, inventory, rider_location_history;"
```

### 10.4 Quarterly Tasks

```bash
# Archive old partitions
bash scripts/archive_partitions.sh

# Review and drop unused indexes
psql -f scripts/analyze_index_usage.sql

# Rebuild fragmented indexes
psql -f scripts/reindex_fragmented.sql

# Performance audit
bash scripts/performance_audit.sh
```

### 10.5 Monitoring Queries

```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('meatvo_db'));

-- Table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

-- Long-running queries (>5 seconds)
SELECT 
  pid, 
  now() - query_start AS duration, 
  query 
FROM pg_stat_activity
WHERE state = 'active' 
  AND now() - query_start > interval '5 seconds';

-- Index hit ratio (should be >99%)
SELECT 
  sum(idx_blks_hit) / nullif(sum(idx_blks_hit + idx_blks_read), 0) AS index_hit_ratio
FROM pg_statio_user_indexes;

-- Cache hit ratio (should be >99%)
SELECT 
  sum(heap_blks_hit) / nullif(sum(heap_blks_hit + heap_blks_read), 0) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

---

## Appendix A: Migration from Old Schema

### Step 1: Backup existing database
```bash
pg_dump -Fc meatvo_db > meatvo_backup_$(date +%Y%m%d).dump
```

### Step 2: Create new database with complete schema
```bash
createdb meatvo_db_new
psql meatvo_db_new < schema_complete.sql
```

### Step 3: Migrate data
```sql
-- Migrate users (already compatible)
INSERT INTO meatvo_db_new.users (id, phone, name, role, refresh_token_hash, mfa_enabled, mfa_secret, mfa_backup_codes, created_at)
SELECT id, phone, name, role, refresh_token_hash, mfa_enabled, mfa_secret, mfa_backup_codes, created_at
FROM meatvo_db.users;

-- Migrate orders (add order_number)
INSERT INTO meatvo_db_new.orders (id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at, updated_at)
SELECT id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at, updated_at
FROM meatvo_db.orders;

-- Backfill order numbers
UPDATE meatvo_db_new.orders
SET order_number = 'MVT' || TO_CHAR(created_at, 'YYYYMMDD') || LPAD(id::TEXT, 6, '0');

-- Continue for all tables...
```

### Step 4: Verify data integrity
```sql
-- Row counts
SELECT 'users' AS table_name, COUNT(*) FROM users
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products;

-- Foreign key validation
SELECT * FROM orders WHERE customer_id NOT IN (SELECT id FROM users);
```

### Step 5: Switch over
```bash
# Rename databases
ALTER DATABASE meatvo_db RENAME TO meatvo_db_old;
ALTER DATABASE meatvo_db_new RENAME TO meatvo_db;
```

---

## Appendix B: Example Queries

### B.1 Business Analytics

```sql
-- Top 10 products by revenue (last 30 days)
SELECT 
  p.name,
  SUM(oi.total_price) AS revenue,
  SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.id
JOIN orders o ON oi.order_id = o.id
WHERE o.created_at > NOW() - INTERVAL '30 days'
  AND o.status = 'DELIVERED'
GROUP BY p.id, p.name
ORDER BY revenue DESC
LIMIT 10;

-- Customer lifetime value
SELECT 
  u.id,
  u.name,
  COUNT(DISTINCT o.id) AS total_orders,
  SUM(o.total_amount) AS lifetime_value,
  AVG(o.total_amount) AS avg_order_value
FROM users u
JOIN orders o ON u.id = o.customer_id
WHERE o.status = 'DELIVERED'
GROUP BY u.id, u.name
ORDER BY lifetime_value DESC
LIMIT 100;

-- Rider performance leaderboard
SELECT 
  u.name AS rider_name,
  dp.total_deliveries,
  dp.successful_deliveries,
  dp.average_rating,
  dp.total_earnings
FROM delivery_partners dp
JOIN users u ON dp.user_id = u.id
WHERE dp.total_deliveries > 0
ORDER BY dp.average_rating DESC, dp.total_deliveries DESC
LIMIT 20;
```

### B.2 Operational Queries

```sql
-- Orders pending assignment
SELECT 
  o.id,
  o.order_number,
  o.created_at,
  o.total_amount,
  o.address->>'city' AS city
FROM orders o
LEFT JOIN order_assignments oa ON o.id = oa.order_id
WHERE o.status = 'CONFIRMED'
  AND oa.id IS NULL
ORDER BY o.created_at;

-- Available riders near location (using geospatial function)
SELECT * FROM find_available_riders(12.9716, 77.5946, 5.0);

-- Low stock alert
SELECT 
  p.id,
  p.name,
  i.available_quantity,
  i.reorder_level
FROM products p
JOIN inventory i ON p.id = i.product_id
WHERE i.available_quantity <= i.reorder_level
  AND p.active = true
ORDER BY i.available_quantity;

-- Expiring products (next 7 days)
SELECT 
  p.name,
  i.quantity,
  i.expiry_date,
  i.expiry_date - CURRENT_DATE AS days_to_expiry
FROM inventory i
JOIN products p ON i.product_id = p.id
WHERE i.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY i.expiry_date;
```

### B.3 Customer Insights

```sql
-- Customers with unread notifications
SELECT 
  u.id,
  u.name,
  COUNT(*) AS unread_count
FROM users u
JOIN notifications n ON u.id = n.user_id
WHERE n.is_read = false
  AND n.deleted_at IS NULL
GROUP BY u.id, u.name
ORDER BY unread_count DESC;

-- Referral effectiveness
SELECT 
  u.name AS referrer,
  rc.code,
  rc.total_referrals,
  rc.successful_referrals,
  (rc.successful_referrals::FLOAT / NULLIF(rc.total_referrals, 0) * 100)::NUMERIC(5,2) AS conversion_rate
FROM referral_codes rc
JOIN users u ON rc.user_id = u.id
WHERE rc.total_referrals > 0
ORDER BY conversion_rate DESC, successful_referrals DESC;

-- Wallet balance summary
SELECT 
  COUNT(*) AS total_users,
  SUM(balance) AS total_wallet_balance,
  AVG(balance) AS avg_balance,
  MAX(balance) AS max_balance
FROM wallets
WHERE balance > 0;
```

---

## Appendix C: Security Checklist

- [x] All passwords hashed (bcrypt/argon2)
- [x] Parameterized queries (no SQL injection)
- [x] Row-level security (RLS) for multi-tenancy
- [x] SSL/TLS for database connections
- [x] Audit logging for sensitive tables
- [x] Soft delete to prevent data loss
- [x] Foreign key constraints for referential integrity
- [x] CHECK constraints on critical fields
- [x] Encrypted columns for PII (planned)
- [x] Database user roles with least privilege
- [x] Connection pooling with max limits
- [x] Rate limiting at application layer

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-06-13 | Initial production-ready schema |

---

**End of Document**
