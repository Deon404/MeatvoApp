-- Add kitchen/staff role for order preparation workflow
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'staff';
