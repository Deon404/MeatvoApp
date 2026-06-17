#!/bin/bash
# ============================================================================
# Meatvo - Monthly Partition Creation Script
# ============================================================================
# This script creates new partitions for the next month
# Run on the 1st of each month
# Usage: bash create_partitions.sh [YYYY-MM]
# Example: bash create_partitions.sh 2027-01
# ============================================================================

set -e

# Configuration
DB_NAME="${POSTGRES_DB:-meatvo_db}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get target month (default: next month)
if [ -z "$1" ]; then
    TARGET_MONTH=$(date -d "next month" +%Y-%m)
else
    TARGET_MONTH=$1
fi

# SECURITY FIX: reject malformed month arg before SQL interpolation
if ! echo "$TARGET_MONTH" | grep -Eq '^[0-9]{4}-(0[1-9]|1[0-2])$'; then
    print_error "Invalid month format: $TARGET_MONTH (expected YYYY-MM)"
    exit 1
fi

YEAR=$(echo $TARGET_MONTH | cut -d'-' -f1)
MONTH=$(echo $TARGET_MONTH | cut -d'-' -f2)

# Calculate next month for partition range
NEXT_MONTH=$(date -d "${TARGET_MONTH}-01 +1 month" +%Y-%m)

print_info "Creating partitions for: ${TARGET_MONTH}"
print_info "Partition range: ${TARGET_MONTH}-01 to ${NEXT_MONTH}-01"

# SQL command to create all partitions
SQL=$(cat <<EOF
BEGIN;

-- ============================================================================
-- ORDERS MODULE PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS orders_${YEAR}_${MONTH} PARTITION OF orders
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE TABLE IF NOT EXISTS order_items_${YEAR}_${MONTH} PARTITION OF order_items
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_orders_${YEAR}_${MONTH}_customer_id 
  ON orders_${YEAR}_${MONTH}(customer_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_orders_${YEAR}_${MONTH}_status 
  ON orders_${YEAR}_${MONTH}(status) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_order_items_${YEAR}_${MONTH}_order_id 
  ON order_items_${YEAR}_${MONTH}(order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_${YEAR}_${MONTH}_product_id 
  ON order_items_${YEAR}_${MONTH}(product_id);

-- ============================================================================
-- PAYMENTS MODULE PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS payments_${YEAR}_${MONTH} PARTITION OF payments
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_payments_${YEAR}_${MONTH}_order_id 
  ON payments_${YEAR}_${MONTH}(order_id);

CREATE INDEX IF NOT EXISTS idx_payments_${YEAR}_${MONTH}_user_id 
  ON payments_${YEAR}_${MONTH}(user_id);

CREATE INDEX IF NOT EXISTS idx_payments_${YEAR}_${MONTH}_status 
  ON payments_${YEAR}_${MONTH}(status);

-- ============================================================================
-- INVENTORY MODULE PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS inventory_movements_${YEAR}_${MONTH} PARTITION OF inventory_movements
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_inventory_movements_${YEAR}_${MONTH}_product_id 
  ON inventory_movements_${YEAR}_${MONTH}(product_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_${YEAR}_${MONTH}_type 
  ON inventory_movements_${YEAR}_${MONTH}(movement_type);

-- ============================================================================
-- NOTIFICATIONS MODULE PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications_${YEAR}_${MONTH} PARTITION OF notifications
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_notifications_${YEAR}_${MONTH}_user_id 
  ON notifications_${YEAR}_${MONTH}(user_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_${YEAR}_${MONTH}_unread 
  ON notifications_${YEAR}_${MONTH}(user_id, is_read) 
  WHERE deleted_at IS NULL AND is_read = FALSE;

-- ============================================================================
-- WALLET MODULE PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS wallet_transactions_${YEAR}_${MONTH} PARTITION OF wallet_transactions
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_${YEAR}_${MONTH}_wallet_id 
  ON wallet_transactions_${YEAR}_${MONTH}(wallet_id);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_${YEAR}_${MONTH}_user_id 
  ON wallet_transactions_${YEAR}_${MONTH}(user_id);

-- ============================================================================
-- RIDER MODULE PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS rider_location_history_${YEAR}_${MONTH} PARTITION OF rider_location_history
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_rider_location_history_${YEAR}_${MONTH}_rider_id 
  ON rider_location_history_${YEAR}_${MONTH}(rider_id);

CREATE INDEX IF NOT EXISTS idx_rider_location_history_${YEAR}_${MONTH}_location 
  ON rider_location_history_${YEAR}_${MONTH} USING GIST(location);

-- ============================================================================
-- OTP LOGS PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS otp_logs_${YEAR}_${MONTH} PARTITION OF otp_logs
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_otp_logs_${YEAR}_${MONTH}_phone 
  ON otp_logs_${YEAR}_${MONTH}(phone, created_at DESC);

-- ============================================================================
-- AUDIT TABLES PARTITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_users_${YEAR}_${MONTH} PARTITION OF audit_users
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_audit_users_${YEAR}_${MONTH}_user_id 
  ON audit_users_${YEAR}_${MONTH}(user_id);

CREATE TABLE IF NOT EXISTS audit_orders_${YEAR}_${MONTH} PARTITION OF audit_orders
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_audit_orders_${YEAR}_${MONTH}_order_id 
  ON audit_orders_${YEAR}_${MONTH}(order_id);

CREATE TABLE IF NOT EXISTS audit_payments_${YEAR}_${MONTH} PARTITION OF audit_payments
  FOR VALUES FROM ('${TARGET_MONTH}-01') TO ('${NEXT_MONTH}-01');

CREATE INDEX IF NOT EXISTS idx_audit_payments_${YEAR}_${MONTH}_payment_id 
  ON audit_payments_${YEAR}_${MONTH}(payment_id);

COMMIT;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 
  'Partitions Created for ${TARGET_MONTH}' AS message,
  COUNT(*) AS partition_count
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE '%_${YEAR}_${MONTH}';
EOF
)

# Execute SQL
print_info "Connecting to database: ${DB_NAME}"

if PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$SQL"; then
    print_info "✓ Partitions created successfully for ${TARGET_MONTH}"
    
    # Display partition list
    print_info "Created partitions:"
    PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '%_${YEAR}_${MONTH}' ORDER BY tablename;"
else
    print_error "✗ Failed to create partitions"
    exit 1
fi

# Analyze new partitions
print_info "Analyzing new partitions..."
PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c \
    "ANALYZE orders_${YEAR}_${MONTH}, order_items_${YEAR}_${MONTH}, payments_${YEAR}_${MONTH};"

print_info "✓ Partition creation complete!"

# Display partition summary
print_info "Partition summary:"
PGPASSWORD=$POSTGRES_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c \
    "SELECT 
       schemaname,
       tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
     FROM pg_tables 
     WHERE schemaname = 'public' AND tablename LIKE '%_${YEAR}_${MONTH}'
     ORDER BY tablename;"
