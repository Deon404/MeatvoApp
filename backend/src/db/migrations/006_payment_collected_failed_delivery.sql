-- LIFECYCLE FIX: COD cash collection status + failed delivery terminal state
-- Run after 005_add_staff_role.sql

ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'FAILED_DELIVERY';

-- Extend payment_status allowed values (drop/recreate CHECK if present)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'orders_payment_status_check'
  ) THEN
    ALTER TABLE orders DROP CONSTRAINT orders_payment_status_check;
  END IF;
END $$;

ALTER TABLE orders
  ADD CONSTRAINT orders_payment_status_check
  CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'COLLECTED'));
