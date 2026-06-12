/**
 * Order Status Migration Script
 * Migrates legacy order statuses to unified status system
 * 
 * Run (terminal): node backend/src/db/migrations/migrate_order_statuses.js
 * Run (pgAdmin):  use migrate_order_statuses.sql — do NOT paste this .js file into SQL
 */

const { query } = require('../postgres');
const { LEGACY_STATUS_MIGRATION } = require('../../utils/orderStatus');

async function migrateOrderStatuses() {
  console.log('Starting order status migration...');
  
  try {
    // Start transaction
    await query('BEGIN');
    
    // Get count of orders with legacy statuses
    const { rows: countRows } = await query(`
      SELECT status, COUNT(*) as count
      FROM orders
      WHERE status IN ('PICKED_UP', 'ON_THE_WAY')
      GROUP BY status
    `);
    
    console.log('Legacy statuses found:', countRows);
    
    // Migrate PICKED_UP and ON_THE_WAY to OUT_FOR_DELIVERY
    for (const [legacyStatus, newStatus] of Object.entries(LEGACY_STATUS_MIGRATION)) {
      const { rowCount } = await query(
        `UPDATE orders 
         SET status = $1
         WHERE status = $2`,
        [newStatus, legacyStatus]
      );
      
      if (rowCount > 0) {
        console.log(`✓ Migrated ${rowCount} orders from ${legacyStatus} to ${newStatus}`);
      }
    }
    
    // Add new status values to enum if they don't exist
    console.log('Checking order_status enum...');
    
    const newStatuses = [
      'PAYMENT_PENDING',
      'PAYMENT_VERIFIED',
      'PACKING_STARTED',
      'RIDER_ASSIGNED',
      'RIDER_ACCEPTED',
      'RIDER_REJECTED',
      'RIDER_NEARBY',
      'REFUNDED',
      'FAILED'
    ];
    
    // Check existing enum values
    const { rows: enumRows } = await query(`
      SELECT e.enumlabel
      FROM pg_type t 
      JOIN pg_enum e ON t.oid = e.enumtypid  
      WHERE t.typname = 'order_status'
    `);
    
    const existingValues = new Set(enumRows.map(r => r.enumlabel));
    
    for (const status of newStatuses) {
      if (!existingValues.has(status)) {
        try {
          await query(`ALTER TYPE order_status ADD VALUE IF NOT EXISTS '${status}'`);
          console.log(`✓ Added ${status} to order_status enum`);
        } catch (err) {
          if (err.code === '42710') {
            // Value already exists, ignore
            console.log(`  ${status} already exists in enum`);
          } else {
            throw err;
          }
        }
      }
    }
    
    // Update order_assignments table to reflect new statuses
    console.log('Updating order_assignments...');
    
    const { rowCount: assignmentCount } = await query(`
      UPDATE order_assignments oa
      SET status = CASE 
        WHEN o.status IN ('OUT_FOR_DELIVERY', 'RIDER_NEARBY') THEN 'PICKED'
        WHEN o.status = 'RIDER_ACCEPTED' THEN 'ACCEPTED'
        WHEN o.status = 'RIDER_ASSIGNED' THEN 'ASSIGNED'
        WHEN o.status = 'DELIVERED' THEN 'DELIVERED'
        WHEN o.status IN ('CANCELLED', 'RIDER_REJECTED') THEN 'CANCELLED'
        ELSE oa.status
      END
      FROM orders o
      WHERE oa.order_id = o.id
      AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED', 'DELIVERED', 'CANCELLED')
    `);
    
    if (assignmentCount > 0) {
      console.log(`✓ Updated ${assignmentCount} order assignments`);
    }
    
    // Commit transaction
    await query('COMMIT');
    
    // Verify migration
    const { rows: verifyRows } = await query(`
      SELECT status, COUNT(*) as count
      FROM orders
      GROUP BY status
      ORDER BY count DESC
    `);
    
    console.log('\n✓ Migration completed successfully!');
    console.log('\nCurrent status distribution:');
    verifyRows.forEach(row => {
      console.log(`  ${row.status}: ${row.count} orders`);
    });
    
    process.exit(0);
    
  } catch (error) {
    // Rollback on error
    await query('ROLLBACK');
    console.error('✗ Migration failed:', error);
    process.exit(1);
  }
}

// Run migration if called directly
if (require.main === module) {
  migrateOrderStatuses();
}

module.exports = { migrateOrderStatuses };
