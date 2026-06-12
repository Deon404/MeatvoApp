# Database Report

## Engine

PostgreSQL via `pg` pool — no ORM. Entry: `backend/src/db/postgres.js`

## Bootstrap Order

1. `backend/src/db/schema.sql`
2. `backend/migrations/004_*.sql`, `005_*.sql`, `006_add_missing_columns.sql`
3. `ensureSchema.js` on every API start
4. Optional: `migrate_order_statuses.js`

## Tables (17 effective)

`users`, `categories`, `products`, `coupons`, `orders`, `order_items`, `delivery_partners`, `order_assignments`, `payment_transactions`, `addresses`, `delivery_slots`, `banners`, `otp_logs`, `app_settings`, `store_settings`, `rider_earnings_history`, `schema_migrations`

## Enums

- `user_role`: admin, customer, delivery
- `order_status`: PLACED … CANCELLED + extended (PAYMENT_PENDING, PACKING_STARTED, etc.)
- `payment_mode`: COD, ONLINE
- `assignment_status`: ASSIGNED … CANCELLED
- `discount_type`: PERCENT, FLAT

## Fixes Applied

| Issue | Fix |
|-------|-----|
| Missing `orders.updated_at` | `ensureSchema.js` + migration 006 |
| Missing `delivery_partners.updated_at` | Same |
| Missing `order_assignments.updated_at` | Same |
| Missing `users.fcm_token` | Same |
| Extended order_status | `ensureSchema.js` enum additions |
| No migration tracking | `schema_migrations` table |
| rider_earnings_history INTEGER FK | Changed to BIGINT |

## Indexes (key)

- `idx_orders_customer_id`, `idx_orders_status`, `idx_orders_payment_status`
- `idx_payment_transactions_gateway_transaction_id`
- `idx_users_fcm_token` (partial)
- `idx_delivery_slots_slot_date_name` (unique)

## Runtime Dependencies

- PostgreSQL connection pool (max 10 default)
- Redis for cart — not stored in PG
- In-memory notifications Map (not persisted)
