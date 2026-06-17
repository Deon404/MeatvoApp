#!/bin/bash
# ============================================================================
# Meatvo - Partition Archival Script
# ============================================================================
# This script detaches and archives old partitions
# Run quarterly to manage database size
# Usage: bash archive_partitions.sh [months_to_keep]
# Example: bash archive_partitions.sh 12  (keeps last 12 months)
# ============================================================================

set -e

# Configuration
DB_NAME="${POSTGRES_DB:-meatvo_db}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
BACKUP_DIR="${BACKUP_DIR:-/backups/partitions}"

# Retention policies (in months)
ORDERS_RETENTION=${ORDERS_RETENTION:-24}
PAYMENTS_RETENTION=${PAYMENTS_RETENTION:-36}
INVENTORY_RETENTION=${INVENTORY_RETENTION:-12}
NOTIFICATIONS_RETENTION=${NOTIFICATIONS_RETENTION:-3}
WALLET_RETENTION=${WALLET_RETENTION:-36}
RIDER_LOCATION_RETENTION=${RIDER_LOCATION_RETENTION:-6}
OTP_RETENTION=${OTP_RETENTION:-1}
AUDIT_RETENTION=${AUDIT_RETENTION:-60}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"
print_info "Backup directory: $BACKUP_DIR"

# Function to archive partition
archive_partition() {
    local table_name=$1
    local partition_name=$2
    local retention_months=$3
    
    print_info "Processing: $partition_name"
    
    # Extract year and month from partition name
    local year_month=$(echo "$partition_name" | grep -oP '\d{4}_\d{2}$')
    local partition_date="${year_month:0:4}-${year_month:5:2}-01"
    
    # Calculate cutoff date
    local cutoff_date=$(date -d "$retention_months months ago" +%Y-%m-01)
    
    if [[ "$partition_date" < "$cutoff_date" ]]; then
        print_warning "Archiving $partition_name (older than $retention_months months)"
        
        # Backup partition
        local backup_file="$BACKUP_DIR/${partition_name}_$(date +%Y%m%d_%H%M%S).sql.gz"
        print_info "Backing up to: $backup_file"
        
        PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            -t "$partition_name" \
            --no-owner \
            --no-acl | gzip > "$backup_file"
        
        if [ $? -eq 0 ]; then
            print_info "✓ Backup successful"
            
            # Detach partition
            print_info "Detaching partition: $partition_name"
            PGPASSWORD=$POSTGRES_PASSWORD psql \
                -h "$DB_HOST" \
                -p "$DB_PORT" \
                -U "$DB_USER" \
                -d "$DB_NAME" \
                -c "ALTER TABLE $table_name DETACH PARTITION $partition_name;"
            
            if [ $? -eq 0 ]; then
                print_info "✓ Partition detached"
                
                # Drop partition (uncomment to enable auto-drop)
                # print_warning "Dropping partition: $partition_name"
                # PGPASSWORD=$POSTGRES_PASSWORD psql \
                #     -h "$DB_HOST" \
                #     -p "$DB_PORT" \
                #     -U "$DB_USER" \
                #     -d "$DB_NAME" \
                #     -c "DROP TABLE $partition_name;"
                # print_info "✓ Partition dropped"
                
                print_info "✓ $partition_name archived successfully"
            else
                print_error "✗ Failed to detach partition"
            fi
        else
            print_error "✗ Backup failed for $partition_name"
        fi
    else
        print_info "Keeping $partition_name (within retention period)"
    fi
}

# Archive orders partitions
print_info "=== Archiving ORDERS partitions (retention: $ORDERS_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'orders_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "orders" "$partition" "$ORDERS_RETENTION"
done

# Archive order_items partitions
print_info "=== Archiving ORDER_ITEMS partitions (retention: $ORDERS_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'order_items_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "order_items" "$partition" "$ORDERS_RETENTION"
done

# Archive payments partitions
print_info "=== Archiving PAYMENTS partitions (retention: $PAYMENTS_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'payments_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "payments" "$partition" "$PAYMENTS_RETENTION"
done

# Archive inventory_movements partitions
print_info "=== Archiving INVENTORY_MOVEMENTS partitions (retention: $INVENTORY_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'inventory_movements_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "inventory_movements" "$partition" "$INVENTORY_RETENTION"
done

# Archive notifications partitions
print_info "=== Archiving NOTIFICATIONS partitions (retention: $NOTIFICATIONS_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'notifications_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "notifications" "$partition" "$NOTIFICATIONS_RETENTION"
done

# Archive wallet_transactions partitions
print_info "=== Archiving WALLET_TRANSACTIONS partitions (retention: $WALLET_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'wallet_transactions_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "wallet_transactions" "$partition" "$WALLET_RETENTION"
done

# Archive rider_location_history partitions
print_info "=== Archiving RIDER_LOCATION_HISTORY partitions (retention: $RIDER_LOCATION_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'rider_location_history_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "rider_location_history" "$partition" "$RIDER_LOCATION_RETENTION"
done

# Archive otp_logs partitions
print_info "=== Archiving OTP_LOGS partitions (retention: $OTP_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'otp_logs_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    archive_partition "otp_logs" "$partition" "$OTP_RETENTION"
done

# Archive audit partitions
print_info "=== Archiving AUDIT partitions (retention: $AUDIT_RETENTION months) ==="
for partition in $(PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'audit_%' AND tablename ~ '^\w+_\d{4}_\d{2}$' ORDER BY tablename;"); do
    local audit_table=$(echo "$partition" | grep -oP '^audit_\w+(?=_\d{4})')
    archive_partition "$audit_table" "$partition" "$AUDIT_RETENTION"
done

# Summary
print_info "=== Archive Summary ==="
print_info "Total backups created: $(ls -1 "$BACKUP_DIR" | wc -l)"
print_info "Backup directory size: $(du -sh "$BACKUP_DIR" | cut -f1)"

# List backups
print_info "Recent backups:"
ls -lhtr "$BACKUP_DIR" | tail -20

print_info "✓ Archive process complete!"
print_warning "NOTE: Detached partitions are still in the database. To drop them, uncomment the DROP TABLE command in this script."
