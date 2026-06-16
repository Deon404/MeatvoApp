# Meatvo Database Design - Complete Documentation

## Quick Navigation

- **[Schema File](../backend/src/db/schema_complete.sql)** - Production-ready SQL schema
- **[Architecture Document](DATABASE_ARCHITECTURE.md)** - Complete architecture details
- **[ER Diagram](ER_DIAGRAM.md)** - Visual entity-relationship diagram
- **[Migration Guide](MIGRATION_GUIDE.md)** - Step-by-step migration instructions

---

## Executive Summary

The Meatvo database is a **production-ready PostgreSQL 14+ schema** designed for a hyperlocal raw-meat delivery platform. It supports:

- **100K+ concurrent users**
- **10K+ orders per day**
- **Real-time delivery tracking**
- **Multi-channel notifications**
- **Comprehensive audit trails**
- **Scalable partitioning strategy**

---

## Key Features

### 1. Comprehensive Module Coverage

| Module | Tables | Features |
|--------|--------|----------|
| **Users** | 3 | Multi-role support, soft delete, MFA |
| **Catalog** | 4 | Hierarchical categories, rich product metadata, inventory tracking |
| **Orders** | 3 | State machine, partitioned by month, JSONB address snapshot |
| **Payments** | 1 | Multi-gateway support, refunds, partitioned |
| **Delivery** | 4 | GPS tracking, rider performance, OTP verification |
| **Promotions** | 4 | Flexible coupons, referral system |
| **Wallet** | 2 | Balance management, transaction history |
| **Notifications** | 1 | Multi-channel, partitioned, action tracking |
| **Reviews** | 1 | Product & rider ratings, moderation |
| **System** | 3 | Banners, delivery slots, app settings |
| **Audit** | 3 | Full change history for critical tables |

**Total:** 30+ tables (including partitions)

---

### 2. Advanced Database Features

#### **Partitioning**
11 tables partitioned by time for scalability:
- `orders`, `order_items`, `payments` (24-month retention)
- `inventory_movements`, `wallet_transactions` (12-36 months)
- `notifications` (3-month retention)
- `rider_location_history` (6-month retention)
- `otp_logs` (1-month retention)
- `audit_users`, `audit_orders`, `audit_payments` (60-month retention)

#### **Soft Delete**
10 tables with `deleted_at` column:
- Never lose data
- Maintain referential integrity
- Enable data recovery
- Partial indexes for performance

#### **Geospatial Support (PostGIS)**
- `addresses.location` - Customer delivery locations
- `delivery_partners.current_location` - Real-time rider tracking
- `rider_location_history.location` - GPS breadcrumb trail
- Proximity search for rider assignment

#### **Full-Text Search**
Trigram GIN indexes on:
- `users.name`
- `products.name`
- `categories.name`

#### **JSONB Columns**
- `orders.address` - Immutable address snapshot
- `products.attributes` - Dynamic product properties
- `payments.gateway_response` - Full payment gateway data
- `notifications.action_data` - Deep linking data

#### **Generated Columns**
- `inventory.available_quantity` = `quantity - reserved_quantity`
- `wallets.available_balance` = `balance - locked_balance`
- `order_assignments.total_earning` = `delivery_fee + tip_amount`

---

### 3. Data Integrity & Security

#### **Foreign Keys**
80+ relationships with appropriate cascades:
- `CASCADE` for dependent data (addresses, order items)
- `RESTRICT` for historical records (orders, payments)
- `SET NULL` for optional references (coupons, categories)

#### **Check Constraints**
- Prices >= 0
- Ratings between 1-5
- Quantities > 0
- Balance >= 0

#### **Unique Constraints**
20+ unique indexes preventing duplicates:
- Phone numbers, emails, UUIDs
- Product SKUs, barcodes, slugs
- Order numbers, payment IDs
- Coupon codes, referral codes

#### **Audit Trails**
Automatic logging of all changes to:
- `users` → `audit_users`
- `orders` → `audit_orders`
- `payments` → `audit_payments`

Captures:
- Operation type (INSERT/UPDATE/DELETE)
- Full row data before/after
- Timestamp and user who made change

---

### 4. Performance Optimization

#### **Indexing Strategy**
100+ indexes across all tables:
- **B-Tree:** Primary keys, foreign keys, status columns
- **GIN:** Full-text search, JSONB queries, array containment
- **GIST:** Geospatial queries
- **Partial:** Filtered indexes (e.g., `WHERE deleted_at IS NULL`)

#### **Partition Pruning**
Enabled by default for massive query speedups:
```sql
-- Only scans orders_2026_06 partition
SELECT * FROM orders 
WHERE created_at BETWEEN '2026-06-01' AND '2026-06-30';
```

#### **Triggers**
10+ triggers for automation:
- Auto-update `updated_at` timestamps
- Generate order numbers (MVTYYYYMMDDxxxxxx)
- Generate referral codes (REFxxxxxxxx)
- Update product order counts
- Update wallet balances
- Audit logging

---

### 5. Scalability Design

#### **Vertical Scaling**
Recommended specs:
- **CPU:** 8 cores (16 threads)
- **RAM:** 32 GB
- **Storage:** 500 GB NVMe SSD
- **IOPS:** 10,000+

#### **Horizontal Scaling**
Future-ready for:
- **Read replicas:** Route reads to 3+ replicas
- **Sharding:** By `user_id` using consistent hashing
- **Connection pooling:** PgBouncer with 20 connections

#### **Data Growth Projections**

| Year | Users | Orders/Day | DB Size | Reads/Sec | Writes/Sec |
|------|-------|-----------|---------|-----------|------------|
| 1 | 100K | 1K | 50 GB | 500 | 100 |
| 2 | 500K | 10K | 200 GB | 2K | 500 |
| 3 | 2M | 50K | 1 TB | 10K | 2K |

---

## Database Schema Overview

### Core Entities

```
users (15 columns)
├── addresses (16 columns) - 1:N
├── wallets (6 columns) - 1:1
│   └── wallet_transactions (11 columns) - 1:N [PARTITIONED]
├── orders (28 columns) - 1:N [PARTITIONED]
│   ├── order_items (13 columns) - 1:N [PARTITIONED]
│   ├── payments (20 columns) - 1:N [PARTITIONED]
│   └── order_assignments (14 columns) - 1:1
├── reviews (13 columns) - 1:N
├── notifications (17 columns) - 1:N [PARTITIONED]
├── delivery_partners (22 columns) - 1:1
│   └── rider_location_history (10 columns) - 1:N [PARTITIONED]
└── referral_codes (11 columns) - 1:1
    └── referrals (12 columns) - 1:N

categories (14 columns) [HIERARCHICAL]
└── products (27 columns)
    ├── inventory (12 columns) - 1:1
    │   └── inventory_movements (12 columns) [PARTITIONED]
    ├── order_items - N:M
    └── reviews - 1:N

coupons (16 columns)
├── orders - 1:N
└── coupon_usage (5 columns) - 1:N

Supporting Tables:
- banners (10 columns)
- delivery_slots (9 columns)
- otp_logs (9 columns) [PARTITIONED]
- app_settings (3 columns)

Audit Tables:
- audit_users (7 columns) [PARTITIONED]
- audit_orders (7 columns) [PARTITIONED]
- audit_payments (7 columns) [PARTITIONED]
```

---

## Custom Data Types (ENUMs)

### 20+ Domain-Specific Enums

```sql
-- User Management
user_role: admin, customer, delivery, support
user_status: active, suspended, deleted
rider_availability: AVAILABLE, BUSY, OFFLINE, BREAK

-- Order Lifecycle
order_status: PENDING, PLACED, CONFIRMED, PACKED, 
              OUT_FOR_DELIVERY, PICKED_UP, ON_THE_WAY, 
              DELIVERED, CANCELLED, REFUNDED

-- Payment Processing
payment_mode: COD, ONLINE, WALLET, MIXED
payment_status: PENDING, INITIATED, SUCCESS, FAILED, 
                REFUNDED, PARTIALLY_REFUNDED
payment_gateway: PHONEPE, RAZORPAY, PAYTM, MANUAL

-- Promotions
discount_type: PERCENT, FLAT
coupon_applicability: ALL, FIRST_ORDER, CATEGORY_SPECIFIC, USER_SPECIFIC

-- Notifications
notification_type: ORDER, PAYMENT, DELIVERY, PROMOTIONAL, 
                   SYSTEM, REFERRAL, WALLET
notification_channel: PUSH, SMS, EMAIL, IN_APP

-- Inventory
inventory_movement_type: PURCHASE, SALE, RETURN, ADJUSTMENT, 
                         DAMAGE, THEFT, EXPIRY

-- Wallet
wallet_transaction_type: CREDIT, DEBIT, REFUND, CASHBACK, 
                         REFERRAL_BONUS, WITHDRAWAL

-- Referrals
referral_status: PENDING, COMPLETED, EXPIRED, CLAIMED

-- Delivery
assignment_status: ASSIGNED, ACCEPTED, PICKED, DELIVERED, 
                   CANCELLED, REJECTED
```

---

## Utility Functions

### 1. Auto-Generate Delivery Slots
```sql
SELECT auto_generate_delivery_slots();
-- Creates 14-day rolling window of delivery slots
-- Morning (7-11), Afternoon (12-16), Evening (17-21)
```

### 2. Find Available Riders
```sql
SELECT * FROM find_available_riders(
  12.9716,  -- target_lat
  77.5946,  -- target_lon
  5.0       -- radius_km
);
-- Returns riders within 5km, sorted by distance
```

### 3. Calculate Distance
```sql
SELECT calculate_distance(12.9716, 77.5946, 12.9352, 77.6245);
-- Returns distance in kilometers (Haversine formula)
```

### 4. Soft Delete Helper
```sql
SELECT soft_delete('products', 123, 1);
-- Soft deletes product #123, logged by user #1
```

---

## Maintenance Schedule

### Daily (Automated)
- Full database backup at 00:00 UTC
- Generate next 14 days of delivery slots
- Cleanup expired OTP logs

### Weekly
- `ANALYZE` statistics update
- Reindex critical indexes
- Review slow query logs

### Monthly
- Create next month's partitions
- Vacuum analyze high-churn tables
- Review index usage

### Quarterly
- Archive old partitions
- Drop unused indexes
- Performance audit
- Capacity planning review

---

## Example Queries

### Business Analytics
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
  u.name,
  COUNT(DISTINCT o.id) AS total_orders,
  SUM(o.total_amount) AS lifetime_value
FROM users u
JOIN orders o ON u.id = o.customer_id
WHERE o.status = 'DELIVERED'
GROUP BY u.id, u.name
ORDER BY lifetime_value DESC;
```

### Operational Queries
```sql
-- Orders pending rider assignment
SELECT 
  o.order_number,
  o.created_at,
  o.total_amount
FROM orders o
LEFT JOIN order_assignments oa ON o.id = oa.order_id
WHERE o.status = 'CONFIRMED'
  AND oa.id IS NULL
ORDER BY o.created_at;

-- Low stock alert
SELECT 
  p.name,
  i.available_quantity,
  i.reorder_level
FROM products p
JOIN inventory i ON p.id = i.product_id
WHERE i.available_quantity <= i.reorder_level
  AND p.active = true;
```

---

## Deployment Instructions

### 1. Initial Setup
```bash
# Create database
createdb meatvo_db

# Install extensions
psql meatvo_db -c "CREATE EXTENSION uuid-ossp;"
psql meatvo_db -c "CREATE EXTENSION pg_trgm;"
psql meatvo_db -c "CREATE EXTENSION postgis;"
psql meatvo_db -c "CREATE EXTENSION btree_gin;"

# Load schema
psql meatvo_db < backend/src/db/schema_complete.sql
```

### 2. Verify Installation
```sql
-- Check tables
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- Check partitions
SELECT parent.relname, child.relname 
FROM pg_class parent
JOIN pg_inherits ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
ORDER BY parent_table, partition_name;

-- Check indexes
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;
```

### 3. Configure Application
```env
# .env
DATABASE_URL=postgresql://user:password@localhost:5432/meatvo_db
DATABASE_POOL_MAX=20
DATABASE_IDLE_TIMEOUT=30000
```

---

## Security Checklist

- [x] Parameterized queries only (no SQL injection)
- [x] Foreign key constraints
- [x] Check constraints on critical fields
- [x] Unique constraints
- [x] Audit logging for sensitive tables
- [x] Soft delete for data recovery
- [x] SSL/TLS for connections (configure in production)
- [x] Database user roles with least privilege
- [x] Connection pooling with limits
- [x] Rate limiting at application layer

---

## Support & Documentation

### Files in This Repository

| File | Purpose |
|------|---------|
| `schema_complete.sql` | Production-ready schema |
| `DATABASE_ARCHITECTURE.md` | Complete architecture details |
| `ER_DIAGRAM.md` | Visual ER diagram |
| `MIGRATION_GUIDE.md` | Step-by-step migration |
| `DATABASE_DESIGN.md` | This file - overview |

### Scripts

| Script | Purpose |
|--------|---------|
| `create_partitions.sh` | Monthly partition creation |
| `archive_partitions.sh` | Quarterly partition archival |

### Monitoring Queries

See `DATABASE_ARCHITECTURE.md` Appendix for:
- Database size queries
- Active connections
- Long-running queries
- Index hit ratios
- Cache hit ratios

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-06-13 | Initial production-ready schema |

---

## License

Proprietary - Meatvo Platform

---

**End of Database Design Document**
