# Meatvo Database Documentation

## Complete PostgreSQL Database Architecture

This directory contains comprehensive documentation for the Meatvo database schema, designed for a hyperlocal raw-meat delivery platform.

---

## 📚 Documentation Index

### 1. **[DATABASE_DESIGN.md](DATABASE_DESIGN.md)** ⭐ START HERE
**Quick overview and executive summary**
- Feature highlights
- Schema overview
- Deployment instructions
- Quick reference

### 2. **[DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md)**
**Complete architectural deep-dive**
- ER diagram description (text-based)
- All tables with columns and data types
- Relationships and foreign keys
- Indexing strategy (100+ indexes)
- Partition strategy (11 partitioned tables)
- Audit architecture
- Soft delete implementation
- Performance optimization
- Scalability roadmap
- Maintenance procedures

### 3. **[ER_DIAGRAM.md](ER_DIAGRAM.md)**
**Visual entity-relationship diagram**
- ASCII art ER diagram
- Cardinality summary (1:1, 1:N, N:M)
- Relationship types (CASCADE, RESTRICT, SET NULL)
- Index catalog
- Partition distribution
- Data types summary
- Constraints summary
- Triggers summary
- Functions summary

### 4. **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)**
**Step-by-step migration from old schema**
- Pre-migration checklist
- Backup procedures
- Blue-green deployment strategy
- Data migration scripts
- Rollback plan
- Post-migration validation
- Common issues & solutions

---

## 🗄️ Schema Files

### Production Schema
- **[backend/src/db/schema_complete.sql](../backend/src/db/schema_complete.sql)**
  - Production-ready PostgreSQL schema
  - 30+ tables
  - 100+ indexes
  - 11 partitioned tables
  - 20+ custom ENUMs
  - 10+ triggers
  - 4 utility functions
  - Ready for 100K+ users

### Legacy Schema
- **[backend/src/db/schema.sql](../backend/src/db/schema.sql)**
  - Existing schema (baseline)
  - Use migration guide to upgrade

---

## 🛠️ Maintenance Scripts

### Located in `backend/scripts/`

#### **create_partitions.sh**
Creates new monthly partitions for 11 partitioned tables
```bash
# Create partitions for next month
bash backend/scripts/create_partitions.sh 2027-01

# Run automatically on 1st of each month (cron)
0 0 1 * * /path/to/create_partitions.sh
```

#### **archive_partitions.sh**
Archives and detaches old partitions based on retention policies
```bash
# Archive partitions older than retention period
bash backend/scripts/archive_partitions.sh

# Run quarterly (cron)
0 0 1 */3 * /path/to/archive_partitions.sh
```

---

## 🚀 Quick Start

### 1. Install Extensions
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
```

### 2. Create Database
```bash
createdb meatvo_db
```

### 3. Load Schema
```bash
psql meatvo_db < backend/src/db/schema_complete.sql
```

### 4. Verify
```sql
-- Check table count
SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';
-- Expected: 30+

-- Check partition count
SELECT COUNT(*) 
FROM pg_class parent
JOIN pg_inherits ON inhparent = parent.oid;
-- Expected: 77+ (7 tables × 11 months)

-- Check indexes
SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';
-- Expected: 100+
```

---

## 📊 Database Statistics

### Modules & Tables

| Module | Tables | Key Features |
|--------|--------|--------------|
| **Users** | 3 | Multi-role, MFA, soft delete |
| **Catalog** | 4 | Hierarchical categories, inventory |
| **Orders** | 3 | Partitioned, state machine |
| **Payments** | 1 | Multi-gateway, partitioned |
| **Delivery** | 4 | GPS tracking, performance metrics |
| **Promotions** | 4 | Coupons, referrals |
| **Wallet** | 2 | Balance, transaction history |
| **Notifications** | 1 | Multi-channel, partitioned |
| **Reviews** | 1 | Product & rider ratings |
| **System** | 3 | Banners, slots, settings |
| **Audit** | 3 | Change history, partitioned |
| **TOTAL** | **30+** | **Production-ready** |

### Data Types

- **Custom ENUMs:** 20+
- **JSONB Columns:** 15+
- **Geospatial (PostGIS):** 4
- **Generated Columns:** 3
- **Array Columns:** 5

### Performance Features

- **Indexes:** 100+
  - B-Tree: 80+
  - GIN (Full-text): 10+
  - GIST (Geospatial): 5+
  - Partial (Filtered): 30+

- **Partitioned Tables:** 11
  - orders, order_items (24 months)
  - payments (36 months)
  - inventory_movements (12 months)
  - notifications (3 months)
  - wallet_transactions (36 months)
  - rider_location_history (6 months)
  - otp_logs (1 month)
  - audit_* (60 months)

- **Triggers:** 10+
  - Auto-update timestamps
  - Generate order numbers
  - Audit logging
  - Wallet balance updates
  - Product order counts

---

## 🔐 Security Features

### Data Protection
- ✅ **Parameterized queries** - No SQL injection
- ✅ **Foreign key constraints** - Referential integrity
- ✅ **Check constraints** - Data validation
- ✅ **Unique constraints** - Prevent duplicates
- ✅ **Soft delete** - Data recovery
- ✅ **Audit trails** - Change history

### Access Control
- ✅ **Role-based permissions** - Least privilege
- ✅ **Connection pooling** - Resource limits
- ✅ **SSL/TLS** - Encrypted connections (configure in prod)

---

## 📈 Scalability

### Current Capacity
- **Users:** 100K+
- **Orders per day:** 10K+
- **Database size:** 200 GB
- **Read QPS:** 2,000
- **Write QPS:** 500

### Horizontal Scaling (Future)
- **Read replicas:** 3+ for read distribution
- **Sharding:** By `user_id` (consistent hashing)
- **Caching:** Redis for hot data

### Vertical Scaling
- **CPU:** 8 cores → 16 cores
- **RAM:** 32 GB → 64 GB
- **Storage:** 500 GB SSD → 1 TB NVMe

---

## 🔧 Maintenance Schedule

### Daily (Automated)
- 00:00 - Full database backup
- 00:05 - Generate delivery slots
- 00:10 - Cleanup expired OTPs

### Weekly
- Sunday 02:00 - Analyze statistics
- Sunday 03:00 - Reindex critical indexes

### Monthly
- 1st - Create next month's partitions
- 15th - Vacuum analyze high-churn tables

### Quarterly
- Archive old partitions
- Drop unused indexes
- Performance audit
- Capacity planning

---

## 📝 Common Queries

### Business Analytics

```sql
-- Revenue by product (last 30 days)
SELECT 
  p.name,
  SUM(oi.total_price) AS revenue
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
  COUNT(DISTINCT o.id) AS orders,
  SUM(o.total_amount) AS ltv
FROM users u
JOIN orders o ON u.id = o.customer_id
WHERE o.status = 'DELIVERED'
GROUP BY u.id, u.name
ORDER BY ltv DESC;
```

### Operations

```sql
-- Orders pending rider assignment
SELECT 
  o.order_number,
  o.created_at,
  o.address->>'city' AS city
FROM orders o
LEFT JOIN order_assignments oa ON o.id = oa.order_id
WHERE o.status = 'CONFIRMED' AND oa.id IS NULL;

-- Low stock products
SELECT 
  p.name,
  i.available_quantity
FROM products p
JOIN inventory i ON p.id = i.product_id
WHERE i.available_quantity <= i.reorder_level;

-- Find nearby riders
SELECT * FROM find_available_riders(12.9716, 77.5946, 5.0);
```

### Monitoring

```sql
-- Database size
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Table sizes
SELECT 
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Cache hit ratio (should be >99%)
SELECT 
  sum(heap_blks_hit) / nullif(sum(heap_blks_hit + heap_blks_read), 0) AS ratio
FROM pg_statio_user_tables;

-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';
```

---

## 🆘 Troubleshooting

### Common Issues

#### 1. Partition Not Found
```sql
-- Check if partition exists for date range
SELECT parent.relname, child.relname 
FROM pg_class parent
JOIN pg_inherits ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
WHERE parent.relname = 'orders';

-- Solution: Run create_partitions.sh for the required month
```

#### 2. Slow Queries
```sql
-- Find slow queries
SELECT 
  pid,
  now() - query_start AS duration,
  query
FROM pg_stat_activity
WHERE state = 'active' 
  AND now() - query_start > interval '5 seconds';

-- Solution: Add missing indexes or optimize query
```

#### 3. Foreign Key Violations
```sql
-- Find orphaned records
SELECT 'orders', COUNT(*) 
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.customer_id);

-- Solution: Clean up orphaned records before migration
```

---

## 📞 Support

### Getting Help

1. **Read the docs** - Start with [DATABASE_DESIGN.md](DATABASE_DESIGN.md)
2. **Check examples** - See query examples above
3. **Review migration** - See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
4. **Check architecture** - Deep dive in [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md)

### Contributing

When updating the schema:

1. Update `schema_complete.sql`
2. Update relevant documentation
3. Test migration scripts
4. Update version history

---

## 📋 Checklist: New Deployment

- [ ] Install PostgreSQL 14+
- [ ] Install extensions (uuid-ossp, pg_trgm, postgis, btree_gin)
- [ ] Create database
- [ ] Load schema_complete.sql
- [ ] Verify table count (30+)
- [ ] Verify partition count (77+)
- [ ] Verify index count (100+)
- [ ] Generate initial delivery slots
- [ ] Create default admin user
- [ ] Configure backups (daily)
- [ ] Set up partition creation (monthly cron)
- [ ] Set up partition archival (quarterly cron)
- [ ] Configure monitoring
- [ ] Test application connection
- [ ] Run smoke tests

---

## 📋 Checklist: Migration from Old Schema

- [ ] Read [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- [ ] Backup current database
- [ ] Test migration on staging
- [ ] Schedule maintenance window
- [ ] Create new database with complete schema
- [ ] Run data migration scripts
- [ ] Verify data integrity
- [ ] Switch over
- [ ] Monitor for 24 hours
- [ ] Keep old database for 30 days (rollback safety)

---

## 📖 References

### PostgreSQL Documentation
- [Partitioning](https://www.postgresql.org/docs/14/ddl-partitioning.html)
- [Indexes](https://www.postgresql.org/docs/14/indexes.html)
- [Triggers](https://www.postgresql.org/docs/14/triggers.html)

### PostGIS Documentation
- [Geography Type](https://postgis.net/docs/using_postgis_dbmanagement.html#Geography_Basics)
- [Spatial Queries](https://postgis.net/docs/reference.html)

### Best Practices
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Database Normalization](https://en.wikipedia.org/wiki/Database_normalization)

---

## 📄 Version

- **Schema Version:** 1.0
- **Documentation Date:** 2026-06-13
- **PostgreSQL Version:** 14+
- **Status:** Production Ready

---

## 📜 License

Proprietary - Meatvo Platform

---

**Happy Database Engineering! 🚀**
