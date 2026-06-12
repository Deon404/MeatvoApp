-- Order Status Migration (SQL) — run in pgAdmin Query Tool
--
-- HOW TO RUN (important):
-- 1. If you see "transaction is aborted", run ONLY this first:
--        ROLLBACK;
-- 2. Run STEP 1 (all ALTER TYPE lines) — select & execute
-- 3. Run STEP 2 (each UPDATE separately, or all together WITHOUT BEGIN/COMMIT)
-- 4. Run STEP 3 to verify
--
-- Do NOT run the whole file at once if STEP 1 already failed inside a transaction.

-- =============================================================================
-- STEP 0: Fix aborted transaction (run this if you got error 25P02)
-- =============================================================================
-- ROLLBACK;

-- =============================================================================
-- STEP 1: Add new enum values (required for app to SET these statuses later)
-- Run each line; skip any that say "already exists"
-- =============================================================================

ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PAYMENT_PENDING';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PAYMENT_VERIFIED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'PACKING_STARTED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_ASSIGNED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_ACCEPTED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_REJECTED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'RIDER_NEARBY';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'REFUNDED';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'FAILED';

-- Confirm new values exist (optional check)
SELECT enumlabel FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'order_status'
ORDER BY enumlabel;

-- =============================================================================
-- STEP 2: Migrate legacy statuses (no BEGIN/COMMIT — safe for pgAdmin)
-- =============================================================================

UPDATE orders
SET status = 'OUT_FOR_DELIVERY'
WHERE status = 'PICKED_UP';

UPDATE orders
SET status = 'OUT_FOR_DELIVERY'
WHERE status = 'ON_THE_WAY';

-- Sync order_assignments (compare status as text — works even before new enum values exist)
UPDATE order_assignments oa
SET status = CASE
  WHEN o.status::text IN ('OUT_FOR_DELIVERY', 'RIDER_NEARBY', 'PICKED_UP', 'ON_THE_WAY') THEN 'PICKED'::assignment_status
  WHEN o.status::text = 'RIDER_ACCEPTED' THEN 'ACCEPTED'::assignment_status
  WHEN o.status::text = 'RIDER_ASSIGNED' THEN 'ASSIGNED'::assignment_status
  WHEN o.status::text = 'DELIVERED' THEN 'DELIVERED'::assignment_status
  WHEN o.status::text IN ('CANCELLED', 'RIDER_REJECTED') THEN 'CANCELLED'::assignment_status
  ELSE oa.status
END
FROM orders o
WHERE oa.order_id = o.id
  AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED', 'DELIVERED', 'CANCELLED');

-- =============================================================================
-- STEP 3: Verify
-- =============================================================================

SELECT status, COUNT(*) AS count
FROM orders
GROUP BY status
ORDER BY count DESC;

SELECT status, COUNT(*) AS count
FROM order_assignments
GROUP BY status
ORDER BY count DESC;
