# Database Audit — Meatvo PostgreSQL

**Date:** 2026-06-12

---

## Schema Overview

| Table | Purpose | FK |
|-------|---------|-----|
| `users` | Phone auth, JWT refresh, MFA | — |
| `categories` | Product taxonomy | — |
| `products` | Catalog items | → categories |
| `coupons` | Discount codes | — |
| `orders` | Order header | → users, coupons |
| `order_items` | Line items | → orders, products |
| `delivery_partners` | Rider profiles | → users (1:1) |
| `order_assignments` | Rider assignment | → orders, delivery_partners |
| `payment_transactions` | PhonePe tracking | → orders |
| `addresses` | Saved addresses | → users |
| `delivery_slots` | Time windows | Auto-seeded |
| `banners` | Home carousel | — |
| `otp_logs` | OTP audit (hashed) | — |
| `app_settings` | Key-value JSONB config | — |
| `store_settings` | Delivery radius, hours | Runtime DDL |
| `rider_earnings_history` | Earnings per delivery | → orders |
| `schema_migrations` | Migration tracking | — |

---

## Enums

- `user_role`: admin, customer, delivery
- `order_status`: PLACED → DELIVERED/CANCELLED (+ extended via migration)
- `payment_mode`: COD, ONLINE
- `assignment_status`: ASSIGNED → DELIVERED/CANCELLED
- `discount_type`: PERCENT, FLAT

---

## Migration System

| Component | Location |
|-----------|----------|
| Bootstrap DDL | `src/db/schema.sql` |
| Runtime patches | `src/db/ensureSchema.js` (every API start) |
| SQL migrations | `migrations/004_*.sql`, `005_*.sql`, `006_*.sql` |
| Runner | `run-migrations.js` (alphabetical, idempotent) |
| Enum extension | `src/db/migrations/migrate_order_statuses.js` |
| Tracking table | `schema_migrations` (added in 006) |

**Gap (resolved):** No migration tracking → `schema_migrations` table added in migration 006.

---

## Critical Issues — Status

| ID | Issue | Status |
|----|-------|--------|
| DB-01 | `orders.updated_at` missing | **Fixed** — schema + migration 006 + ensureSchema |
| DB-02 | `delivery_partners.updated_at` missing | **Fixed** |
| DB-03 | `order_assignments.updated_at` missing | **Fixed** |
| DB-04 | Extended order_status values | **Fixed** — migrate_order_statuses.js |
| DB-05 | No migration tracking | **Fixed** — schema_migrations table |
| DB-06 | rider_earnings_history FK type mismatch | **Partial** — ensureSchema uses BIGINT |

---

## Indexes (25+)

- PKs on all tables
- FK indexes: `orders.customer_id`, `order_items.order_id`, etc.
- Partial: `idx_users_fcm_token WHERE fcm_token IS NOT NULL`
- Composite recommended: `orders(customer_id, status)` — add if query plans show seq scans

---

## Foreign Keys

All core relationships enforced. `ON DELETE RESTRICT` on orders→users prevents orphan orders. `CASCADE` on order_items→orders.

---

## Runtime Schema Mismatches

`ensureSchema.js` runs 40+ idempotent ALTER/CREATE statements on boot — catches drift between migration files and code expectations. Safe for production fresh installs and upgrades.

---

## Recommended Production Migration Sequence

```bash
psql -U meatvo_user -d meatvo_db -f backend/src/db/schema.sql
cd backend && node run-migrations.js
node src/db/migrations/migrate_order_statuses.js
# ensureSchema runs automatically on PM2 start
```

---

## Orphan / Unused Tables

No orphan tables detected. `otp_logs` grows unbounded — consider retention job (30-day purge).

---

## Generated Migrations

| File | Purpose |
|------|---------|
| `migrations/006_add_missing_columns.sql` | updated_at columns, fcm_token, schema_migrations |

No additional migrations required for current codebase.
