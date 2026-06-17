-- Migration 007: Add Cashfree payment gateway support (fixed)

-- 1. Create enum only if it doesn't exist
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_gateway') THEN
    CREATE TYPE payment_gateway AS ENUM ('PHONEPE', 'RAZORPAY', 'PAYTM', 'MANUAL', 'CASHFREE');
  ELSE
    -- Enum exists, just add CASHFREE if missing
    ALTER TYPE payment_gateway ADD VALUE IF NOT EXISTS 'CASHFREE';
  END IF;
END $$;

-- 2. Add gateway columns to payment_transactions if not exists
ALTER TABLE payment_transactions 
  ADD COLUMN IF NOT EXISTS gateway_order_id VARCHAR(100),
  ADD COLUMN IF NOT EXISTS gateway_payment_id VARCHAR(100);

-- 3. Add index for gateway_order_id lookups
CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_order_id 
  ON payment_transactions(gateway_order_id);

-- 4. Update default gateway for new rows
ALTER TABLE payment_transactions 
  ALTER COLUMN gateway SET DEFAULT 'CASHFREE';

-- Verify
SELECT enum_range(NULL::payment_gateway);
