# Meatvo Database - Entity-Relationship Diagram

## Visual ER Diagram (Text-Based)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                  MEATVO DATABASE                                       │
│                               Entity-Relationship Diagram                              │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              USER MANAGEMENT DOMAIN                                   │
└──────────────────────────────────────────────────────────────────────────────────────┘

                            ┌─────────────────────────┐
                            │        USERS            │
                            │─────────────────────────│
                            │ PK id                   │
                            │    uuid (UNIQUE)        │
                            │    phone (UNIQUE)       │
                            │    email (UNIQUE)       │
                            │    name                 │
                            │    role (ENUM)          │
                            │    status (ENUM)        │
                            │    deleted_at           │
                            └────────┬────────────────┘
                                     │
              ┏━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━┓
              ┃                      │                       ┃
              ┃                      │                       ┃
    ┌─────────▼──────────┐  ┌────────▼──────────┐  ┌────────▼─────────┐
    │    ADDRESSES       │  │      WALLETS      │  │   REVIEWS        │
    │────────────────────│  │───────────────────│  │──────────────────│
    │ PK id              │  │ PK id             │  │ PK id            │
    │ FK user_id         │  │ FK user_id        │  │ FK user_id       │
    │    address_line_1  │  │    balance        │  │ FK order_id      │
    │    pincode         │  │    locked_balance │  │ FK product_id    │
    │    location (GEO)  │  │    available      │  │ FK rider_id      │
    │    is_default      │  └─────────┬─────────┘  │    rating        │
    │    deleted_at      │            │            │    review_text   │
    └────────────────────┘            │            └──────────────────┘
                                      │
                          ┌───────────▼───────────┐
                          │ WALLET_TRANSACTIONS   │
                          │   (PARTITIONED)       │
                          │───────────────────────│
                          │ PK id                 │
                          │ FK wallet_id          │
                          │ FK user_id            │
                          │    transaction_type   │
                          │    amount             │
                          │    balance_before     │
                          │    balance_after      │
                          │    reference_type     │
                          │    reference_id       │
                          └───────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            PRODUCT CATALOG DOMAIN                                     │
└──────────────────────────────────────────────────────────────────────────────────────┘

        ┌─────────────────────────┐
        │      CATEGORIES         │
        │─────────────────────────│
        │ PK id                   │
        │ FK parent_id (SELF)     │
        │    name                 │
        │    slug (UNIQUE)        │
        │    path (HIERARCHY)     │
        │    level                │
        │    sort_order           │
        │    active               │
        │    deleted_at           │
        └──────────┬──────────────┘
                   │
                   │ 1:N
                   │
        ┌──────────▼──────────────┐
        │       PRODUCTS          │
        │─────────────────────────│
        │ PK id                   │
        │ FK category_id          │
        │    name                 │
        │    slug (UNIQUE)        │
        │    sku (UNIQUE)         │
        │    barcode (UNIQUE)     │
        │    price                │
        │    mrp                  │
        │    tags[] (ARRAY)       │
        │    attributes (JSONB)   │
        │    active               │
        │    deleted_at           │
        └──────────┬──────────────┘
                   │
                   │ 1:1
                   │
        ┌──────────▼──────────────┐
        │      INVENTORY          │
        │─────────────────────────│
        │ PK id                   │
        │ FK product_id (UNIQUE)  │
        │    quantity             │
        │    reserved_quantity    │
        │    available (COMPUTED) │
        │    reorder_level        │
        │    expiry_date          │
        └──────────┬──────────────┘
                   │
                   │ 1:N (AUDIT)
                   │
        ┌──────────▼──────────────┐
        │ INVENTORY_MOVEMENTS     │
        │    (PARTITIONED)        │
        │─────────────────────────│
        │ PK id                   │
        │ FK product_id           │
        │    movement_type        │
        │    quantity             │
        │    previous_quantity    │
        │    new_quantity         │
        │    reference_type       │
        │    reference_id         │
        └─────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                               ORDER MANAGEMENT DOMAIN                                 │
└──────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────┐
    │        ORDERS           │
    │    (PARTITIONED)        │
    │─────────────────────────│
    │ PK id                   │
    │    order_number (UNIQUE)│
    │ FK customer_id → users  │
    │ FK address_id           │
    │ FK coupon_id            │
    │    status (ENUM)        │
    │    subtotal             │
    │    discount_amount      │
    │    delivery_fee         │
    │    tax_amount           │
    │    total_amount         │
    │    address (JSONB)      │
    │    payment_mode         │
    │    deleted_at           │
    └──────┬──────────────┬───┘
           │              │
           │ 1:N          │ 1:N
           │              │
    ┌──────▼──────────┐   │   ┌───────────────────┐
    │  ORDER_ITEMS    │   │   │    PAYMENTS       │
    │ (PARTITIONED)   │   │   │  (PARTITIONED)    │
    │─────────────────│   │   │───────────────────│
    │ PK id           │   │   │ PK id             │
    │ FK order_id     │   │   │    payment_id     │
    │ FK product_id   │   │   │ FK order_id       │
    │    product_name │   │   │ FK user_id        │
    │    quantity     │   │   │    amount         │
    │    unit_price   │   │   │    payment_mode   │
    │    total_price  │   │   │    payment_gateway│
    │    attributes   │   │   │    status (ENUM)  │
    └─────────────────┘   │   │    gateway_txn_id │
                          │   │    refund_amount  │
                          │   └───────────────────┘
                          │
                          │ 1:1
                          │
                    ┌─────▼───────────────┐
                    │ ORDER_ASSIGNMENTS   │
                    │─────────────────────│
                    │ PK id               │
                    │ FK order_id (UNIQUE)│
                    │ FK rider_id         │
                    │    status (ENUM)    │
                    │    pickup_otp       │
                    │    delivery_otp     │
                    │    delivery_image   │
                    │    delivery_fee     │
                    │    tip_amount       │
                    │    total_earning    │
                    └─────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              DELIVERY PARTNER DOMAIN                                  │
└──────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────┐
    │   DELIVERY_PARTNERS     │
    │─────────────────────────│
    │ PK id                   │
    │ FK user_id (UNIQUE)     │
    │    availability (ENUM)  │
    │    approved             │
    │    current_lat          │
    │    current_lng          │
    │    current_location(GEO)│
    │    vehicle_type         │
    │    vehicle_number       │
    │    total_deliveries     │
    │    average_rating       │
    │    total_earnings       │
    │    deleted_at           │
    └──────────┬──────────────┘
               │
               │ 1:N
               │
    ┌──────────▼──────────────┐
    │ RIDER_LOCATION_HISTORY  │
    │    (PARTITIONED)        │
    │─────────────────────────│
    │ PK id                   │
    │ FK rider_id             │
    │ FK order_id             │
    │    latitude             │
    │    longitude            │
    │    location (GEO)       │
    │    accuracy             │
    │    speed                │
    │    bearing              │
    │    recorded_at          │
    └─────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            PROMOTIONS & ENGAGEMENT DOMAIN                             │
└──────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────┐          ┌─────────────────────────┐
    │       COUPONS           │          │   REFERRAL_CODES        │
    │─────────────────────────│          │─────────────────────────│
    │ PK id                   │          │ PK id                   │
    │    code (UNIQUE)        │          │ FK user_id (UNIQUE)     │
    │    discount_type        │          │    code (UNIQUE)        │
    │    discount_value       │          │    referrer_reward      │
    │    min_order_value      │          │    referee_reward       │
    │    applicability        │          │    total_referrals      │
    │    applicable_categories│          │    successful_referrals │
    │    max_uses             │          │    active               │
    │    valid_from           │          └──────────┬──────────────┘
    │    valid_to             │                     │
    │    deleted_at           │                     │ 1:N
    └──────────┬──────────────┘                     │
               │                          ┌─────────▼──────────────┐
               │ 1:N                      │      REFERRALS         │
               │                          │────────────────────────│
    ┌──────────▼──────────────┐          │ PK id                  │
    │    COUPON_USAGE         │          │ FK referral_code_id    │
    │─────────────────────────│          │ FK referrer_id → users │
    │ PK id                   │          │ FK referee_id → users  │
    │ FK coupon_id            │          │ FK referee_order_id    │
    │ FK user_id              │          │    status (ENUM)       │
    │ FK order_id             │          │    referrer_reward     │
    │    discount_amount      │          │    referee_reward      │
    └─────────────────────────┘          │    completed_at        │
                                         │    expires_at          │
                                         └────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              NOTIFICATIONS DOMAIN                                     │
└──────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────┐
    │    NOTIFICATIONS        │
    │    (PARTITIONED)        │
    │─────────────────────────│
    │ PK id                   │
    │ FK user_id              │
    │    type (ENUM)          │
    │    channel (ENUM)       │
    │    title                │
    │    body                 │
    │    action_url           │
    │    action_data (JSONB)  │
    │    reference_type       │
    │    reference_id         │
    │    is_read              │
    │    sent                 │
    │    deleted_at           │
    └─────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              SUPPORTING TABLES                                        │
└──────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
    │     BANNERS         │  │  DELIVERY_SLOTS     │  │    OTP_LOGS         │
    │─────────────────────│  │─────────────────────│  │  (PARTITIONED)      │
    │ PK id               │  │ PK id               │  │─────────────────────│
    │    title            │  │    name             │  │ PK id               │
    │    image_url        │  │    start_time       │  │    phone            │
    │    action_type      │  │    end_time         │  │    otp              │
    │    action_value     │  │    slot_date        │  │    verified         │
    │    active           │  │    capacity         │  │    expires_at       │
    │    deleted_at       │  │    booked           │  └─────────────────────┘
    └─────────────────────┘  │    available        │
                             │    is_active        │  ┌─────────────────────┐
                             └─────────────────────┘  │   APP_SETTINGS      │
                                                      │─────────────────────│
                                                      │ PK key              │
                                                      │    value (JSONB)    │
                                                      │    description      │
                                                      └─────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                 AUDIT TABLES                                          │
└──────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
    │   AUDIT_USERS       │  │  AUDIT_ORDERS       │  │  AUDIT_PAYMENTS     │
    │  (PARTITIONED)      │  │  (PARTITIONED)      │  │  (PARTITIONED)      │
    │─────────────────────│  │─────────────────────│  │─────────────────────│
    │ PK audit_id         │  │ PK audit_id         │  │ PK audit_id         │
    │    operation        │  │    operation        │  │    operation        │
    │    user_id          │  │    order_id         │  │    payment_id       │
    │    old_data (JSONB) │  │    old_data (JSONB) │  │    old_data (JSONB) │
    │    new_data (JSONB) │  │    new_data (JSONB) │  │    new_data (JSONB) │
    │    changed_by       │  │    changed_by       │  │    changed_by       │
    │    changed_at       │  │    changed_at       │  │    changed_at       │
    └─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

## Cardinality Summary

### One-to-One (1:1)
- `users` ← → `wallets`
- `users` ← → `delivery_partners`
- `users` ← → `referral_codes`
- `products` ← → `inventory`
- `orders` ← → `order_assignments`

### One-to-Many (1:N)
- `users` → `addresses`
- `users` → `orders`
- `users` → `reviews`
- `users` → `notifications`
- `categories` → `products` (category hierarchy is self-referencing)
- `categories` → `categories` (parent-child)
- `products` → `order_items`
- `products` → `reviews`
- `products` → `inventory_movements`
- `orders` → `order_items`
- `orders` → `payments`
- `coupons` → `orders`
- `coupons` → `coupon_usage`
- `delivery_partners` → `order_assignments`
- `delivery_partners` → `rider_location_history`
- `wallets` → `wallet_transactions`
- `referral_codes` → `referrals`

### Many-to-One (N:1)
All foreign key relationships follow N:1 from the child table perspective.

### Many-to-Many (M:N)
- `users` ← → `products` (via `reviews`)
- `users` ← → `products` (via `order_items` → `orders`)
- `categories` ← → `coupons` (via `applicable_categories` array)

## Relationship Types

### CASCADE DELETE
- `addresses` → `users` (ON DELETE CASCADE)
- `delivery_partners` → `users` (ON DELETE CASCADE)
- `order_items` → `orders` (ON DELETE CASCADE)
- `order_assignments` → `orders` (ON DELETE CASCADE)
- `wallet_transactions` → `wallets` (ON DELETE CASCADE)
- `inventory` → `products` (ON DELETE CASCADE)

### RESTRICT DELETE
- `orders` → `users` (ON DELETE RESTRICT) - Cannot delete customer with orders
- `order_items` → `products` (ON DELETE RESTRICT) - Cannot delete product with order history
- `payments` → `users` (ON DELETE RESTRICT)
- `order_assignments` → `delivery_partners` (ON DELETE RESTRICT)

### SET NULL
- `products` → `categories` (ON DELETE SET NULL) - Product becomes uncategorized
- `orders` → `coupons` (ON DELETE SET NULL) - Order keeps discount but loses coupon reference
- `orders` → `addresses` (ON DELETE SET NULL) - Order keeps JSONB address snapshot

## Indexes Summary

### B-Tree Indexes (Standard)
- All primary keys (automatic)
- All foreign keys (explicit)
- Unique constraints (phone, email, slug, code, order_number)
- Status and enum columns
- Timestamp columns for ordering

### GIN Indexes (Full-Text & Array)
- `products.tags` - Array containment
- `products.name`, `categories.name`, `users.name` - Trigram full-text search
- JSONB columns for attribute queries

### GIST Indexes (Geospatial)
- `addresses.location`
- `delivery_partners.current_location`
- `rider_location_history.location`

### Partial Indexes (Filtered)
- Most indexes include `WHERE deleted_at IS NULL`
- `idx_inventory_low_stock` - `WHERE available_quantity <= reorder_level`
- `idx_notifications_unread` - `WHERE is_read = FALSE`

## Partition Distribution

### Monthly Partitions (High-Volume Tables)
- `orders` - Partition by `created_at`
- `order_items` - Partition by `created_at` (matches orders)
- `payments` - Partition by `created_at`
- `inventory_movements` - Partition by `created_at`
- `notifications` - Partition by `created_at`
- `wallet_transactions` - Partition by `created_at`
- `rider_location_history` - Partition by `created_at`
- `otp_logs` - Partition by `created_at`
- `audit_users` - Partition by `changed_at`
- `audit_orders` - Partition by `changed_at`
- `audit_payments` - Partition by `changed_at`

### Non-Partitioned Tables
All other tables (users, products, categories, etc.)

## Soft Delete Strategy

Tables with `deleted_at` column:
- `users`
- `addresses`
- `categories`
- `products`
- `coupons`
- `orders`
- `delivery_partners`
- `notifications`
- `reviews`
- `banners`

Immutable tables (no soft delete):
- `order_items` - Order history
- `payments` - Financial audit
- `inventory` - Real-time stock
- `wallets` - Financial balances
- All audit tables
- All partitioned transaction tables

## Data Types Summary

### Numeric Types
- `BIGSERIAL` - Primary keys (auto-increment)
- `BIGINT` - Foreign keys
- `INTEGER` - Counts, quantities
- `NUMERIC(10,2)` - Money (prices, amounts)
- `NUMERIC(10,7)` - GPS coordinates (lat/lng)

### Text Types
- `VARCHAR(n)` - Fixed-length strings with limit
- `TEXT` - Variable-length text (no limit)
- `TEXT[]` - Array of strings

### Date/Time Types
- `TIMESTAMPTZ` - Timestamps with timezone
- `DATE` - Date only (no time)
- `TIME` - Time only (no date)

### Complex Types
- `JSONB` - JSON data (indexed)
- `GEOGRAPHY(POINT, 4326)` - PostGIS geospatial point
- `UUID` - Universally unique identifier
- Custom ENUMs - 20+ domain-specific enums

### Boolean
- `BOOLEAN` - True/false flags

## Constraints Summary

### Primary Keys
All tables have `id BIGSERIAL PRIMARY KEY`

### Foreign Keys
80+ foreign key relationships (see relationships above)

### Unique Constraints
- `users.phone`, `users.email`, `users.uuid`
- `products.slug`, `products.sku`, `products.barcode`
- `categories.slug`
- `coupons.code`
- `orders.order_number`
- `payments.payment_id`
- `referral_codes.code`
- `wallets.user_id`
- `delivery_partners.user_id`
- `order_assignments.order_id`

### Check Constraints
- `price >= 0`, `mrp >= price`
- `quantity > 0` (order items)
- `balance >= 0` (wallets)
- `rating >= 1 AND rating <= 5` (reviews)
- `average_rating >= 0 AND average_rating <= 5`

### Generated Columns (COMPUTED)
- `inventory.available_quantity` = `quantity - reserved_quantity`
- `wallets.available_balance` = `balance - locked_balance`
- `order_assignments.total_earning` = `delivery_fee + tip_amount`

## Triggers Summary

### Auto-Update Triggers
- `update_updated_at_column()` - Updates `updated_at` on 10+ tables

### Auto-Generate Triggers
- `generate_order_number()` - Creates MVTYYYYMMDDxxxxxx format
- `generate_referral_code()` - Creates REFxxxxxxxx format

### Side-Effect Triggers
- `update_product_order_count()` - Increments `product.order_count`
- `update_wallet_balance()` - Updates `wallet.balance` on transaction

### Audit Triggers
- `audit_users_changes()` - Logs all user table changes
- `audit_orders_changes()` - Logs all order table changes
- `audit_payments_changes()` - Logs all payment table changes

## Functions Summary

### Utility Functions
- `auto_generate_delivery_slots()` - Creates 14-day delivery slot window
- `calculate_distance(lat1, lon1, lat2, lon2)` - Haversine distance formula
- `find_available_riders(lat, lon, radius)` - Geospatial rider search
- `soft_delete(table_name, record_id, deleted_by)` - Generic soft delete helper

---

**Last Updated:** 2026-06-13
