# Database Maintenance Scripts

## Overview

This directory contains scripts for maintaining the Meatvo PostgreSQL database, specifically for managing partitioned tables.

---

## Scripts

### 1. `create_partitions.sh`

**Purpose:** Create new monthly partitions for all partitioned tables

**Schedule:** Run on the 1st of each month

**Usage:**
```bash
# Create partitions for next month (auto-detects)
bash create_partitions.sh

# Create partitions for specific month
bash create_partitions.sh 2027-01
```

**What it does:**
- Creates partitions for 11 partitioned tables:
  - `orders`
  - `order_items`
  - `payments`
  - `inventory_movements`
  - `notifications`
  - `wallet_transactions`
  - `rider_location_history`
  - `otp_logs`
  - `audit_users`
  - `audit_orders`
  - `audit_payments`
- Creates indexes on new partitions
- Runs ANALYZE on new partitions

**Configuration:**
```bash
export POSTGRES_DB=meatvo_db
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=yourpassword
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
```

**Cron Setup:**
```bash
# Add to crontab (run at 00:00 on 1st of every month)
0 0 1 * * cd /path/to/project && bash backend/scripts/create_partitions.sh >> /var/log/meatvo/partitions.log 2>&1
```

---

### 2. `archive_partitions.sh`

**Purpose:** Archive and detach old partitions based on retention policies

**Schedule:** Run quarterly

**Usage:**
```bash
# Archive partitions (uses default retention policies)
bash archive_partitions.sh
```

**Retention Policies:**
| Table | Retention | Environment Variable |
|-------|-----------|---------------------|
| orders | 24 months | ORDERS_RETENTION |
| payments | 36 months | PAYMENTS_RETENTION |
| inventory_movements | 12 months | INVENTORY_RETENTION |
| notifications | 3 months | NOTIFICATIONS_RETENTION |
| wallet_transactions | 36 months | WALLET_RETENTION |
| rider_location_history | 6 months | RIDER_LOCATION_RETENTION |
| otp_logs | 1 month | OTP_RETENTION |
| audit_* | 60 months | AUDIT_RETENTION |

**What it does:**
1. Backs up old partitions to gzip files
2. Detaches partitions from parent table
3. **Does NOT drop partitions** (uncomment in script to enable)
4. Saves backups to `/backups/partitions/`

**Configuration:**
```bash
export POSTGRES_DB=meatvo_db
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=yourpassword
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export BACKUP_DIR=/backups/partitions

# Override retention policies (in months)
export ORDERS_RETENTION=24
export PAYMENTS_RETENTION=36
export NOTIFICATIONS_RETENTION=3
```

**Cron Setup:**
```bash
# Add to crontab (run at 00:00 on 1st of Jan, Apr, Jul, Oct)
0 0 1 1,4,7,10 * cd /path/to/project && bash backend/scripts/archive_partitions.sh >> /var/log/meatvo/archive.log 2>&1
```

---

## Setup Instructions

### 1. Make Scripts Executable
```bash
chmod +x backend/scripts/*.sh
```

### 2. Create Log Directory
```bash
mkdir -p /var/log/meatvo
```

### 3. Create Backup Directory
```bash
mkdir -p /backups/partitions
```

### 4. Configure Environment Variables

Create `/etc/meatvo/db.env`:
```bash
POSTGRES_DB=meatvo_db
POSTGRES_USER=meatvo_user
POSTGRES_PASSWORD=secure_password
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
BACKUP_DIR=/backups/partitions
```

Load in scripts:
```bash
# Add to top of scripts
source /etc/meatvo/db.env
```

### 5. Set Up Cron Jobs

Edit crontab:
```bash
crontab -e
```

Add:
```bash
# Load environment
SHELL=/bin/bash
BASH_ENV=/etc/meatvo/db.env

# Create partitions monthly
0 0 1 * * cd /path/to/MeatvoApp && bash backend/scripts/create_partitions.sh >> /var/log/meatvo/partitions.log 2>&1

# Archive partitions quarterly
0 0 1 1,4,7,10 * cd /path/to/MeatvoApp && bash backend/scripts/archive_partitions.sh >> /var/log/meatvo/archive.log 2>&1
```

---

## Monitoring

### Check Partition Creation
```sql
-- List all partitions
SELECT 
  parent.relname AS parent_table,
  child.relname AS partition_name,
  pg_get_expr(child.relpartbound, child.oid) AS partition_range,
  pg_size_pretty(pg_total_relation_size(child.oid)) AS size
FROM pg_class parent
JOIN pg_inherits ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
WHERE parent.relname IN ('orders', 'payments', 'notifications')
ORDER BY parent_table, partition_name;
```

### Check Backup Files
```bash
# List recent backups
ls -lhtr /backups/partitions/

# Check backup size
du -sh /backups/partitions/
```

### View Logs
```bash
# Partition creation log
tail -f /var/log/meatvo/partitions.log

# Archive log
tail -f /var/log/meatvo/archive.log
```

---

## Troubleshooting

### Issue: Permission Denied

**Problem:** Script cannot connect to database

**Solution:**
```bash
# Check pg_hba.conf allows local connections
sudo vim /etc/postgresql/14/main/pg_hba.conf

# Add:
local   all             meatvo_user                             md5
host    all             meatvo_user     127.0.0.1/32            md5
host    all             meatvo_user     ::1/128                 md5

# Reload PostgreSQL
sudo systemctl reload postgresql
```

### Issue: Partition Already Exists

**Problem:** Script fails because partition already exists

**Solution:** Script handles this with `IF NOT EXISTS` - safe to rerun

### Issue: Backup Directory Full

**Problem:** `/backups/partitions/` running out of space

**Solution:**
```bash
# Find old backups
find /backups/partitions/ -name "*.sql.gz" -mtime +90

# Delete backups older than 90 days
find /backups/partitions/ -name "*.sql.gz" -mtime +90 -delete

# Or move to cold storage
find /backups/partitions/ -name "*.sql.gz" -mtime +90 -exec mv {} /cold-storage/ \;
```

### Issue: Script Hangs

**Problem:** Script takes too long

**Solution:**
```bash
# Check long-running queries
psql -U postgres -d meatvo_db -c "
SELECT 
  pid,
  now() - query_start AS duration,
  query
FROM pg_stat_activity
WHERE state = 'active' 
  AND now() - query_start > interval '5 minutes';"

# Kill if necessary
psql -U postgres -d meatvo_db -c "SELECT pg_terminate_backend(12345);"
```

---

## Best Practices

### 1. Test First
Always test scripts on staging before production:
```bash
# Test on staging database
export POSTGRES_DB=meatvo_db_staging
bash create_partitions.sh
```

### 2. Monitor Disk Space
Keep 2x partition size free for reindexing:
```bash
# Check available space
df -h /var/lib/postgresql
```

### 3. Verify Backups
Periodically test backup restoration:
```bash
# Restore backup to test database
createdb test_restore
gunzip -c /backups/partitions/orders_2026_01.sql.gz | psql test_restore
```

### 4. Keep Logs
Rotate logs to prevent disk fill:
```bash
# /etc/logrotate.d/meatvo
/var/log/meatvo/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## Advanced Usage

### Manual Partition Creation

```bash
# Create partitions for next 3 months
for month in {1..3}; do
  bash create_partitions.sh $(date -d "+${month} months" +%Y-%m)
done
```

### Selective Archival

```bash
# Archive only notifications (short retention)
export BACKUP_DIR=/backups/notifications
export ORDERS_RETENTION=999  # Don't archive orders
export NOTIFICATIONS_RETENTION=3
bash archive_partitions.sh
```

### Dry Run Mode

Add to script for testing:
```bash
# Add at top of script
DRY_RUN=true  # Set to false for actual execution

# Modify execution blocks
if [ "$DRY_RUN" = "false" ]; then
  psql -c "$SQL"
else
  echo "DRY RUN: Would execute: $SQL"
fi
```

---

## Script Output Examples

### Successful Partition Creation
```
[INFO] Creating partitions for: 2027-01
[INFO] Partition range: 2027-01-01 to 2027-02-01
[INFO] Connecting to database: meatvo_db
[INFO] ✓ Partitions created successfully for 2027-01
[INFO] Created partitions:
 orders_2027_01
 order_items_2027_01
 payments_2027_01
 [... 11 total ...]
[INFO] Analyzing new partitions...
[INFO] ✓ Partition creation complete!
```

### Successful Archival
```
[INFO] Backup directory: /backups/partitions
[INFO] === Archiving ORDERS partitions (retention: 24 months) ===
[INFO] Processing: orders_2024_06
[WARNING] Archiving orders_2024_06 (older than 24 months)
[INFO] Backing up to: /backups/partitions/orders_2024_06_20260613_120000.sql.gz
[INFO] ✓ Backup successful
[INFO] Detaching partition: orders_2024_06
[INFO] ✓ Partition detached
[INFO] ✓ orders_2024_06 archived successfully
[INFO] === Archive Summary ===
[INFO] Total backups created: 23
[INFO] Backup directory size: 4.2G
```

---

## Support

For issues or questions:
1. Check PostgreSQL logs: `/var/log/postgresql/`
2. Check script logs: `/var/log/meatvo/`
3. Review database documentation: `docs/DATABASE_ARCHITECTURE.md`

---

**Last Updated:** 2026-06-13
