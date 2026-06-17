-- Delivery slots: capacity-based booking aligned with slots.controller.js / orders.controller.js

BEGIN;

-- Drop legacy shape (UUID id + date/slot_time) if present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'delivery_slots'
      AND column_name = 'slot_time'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'delivery_slots'
      AND column_name = 'slot_date'
  ) THEN
    DROP TABLE IF EXISTS delivery_slots CASCADE;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS delivery_slots (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_date DATE NOT NULL,
  capacity INT NOT NULL DEFAULT 20,
  booked INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_slots_slot_date_name ON delivery_slots(slot_date, name);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_slot_date ON delivery_slots(slot_date);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_active_date ON delivery_slots(is_active, slot_date);

CREATE OR REPLACE FUNCTION auto_generate_delivery_slots()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delivery slots are admin-managed (today + 2 days). No automatic Morning/Evening seeding.
  RETURN;
END;
$$;

-- No automatic slot seed; admin creates slots with custom times.

COMMIT;
