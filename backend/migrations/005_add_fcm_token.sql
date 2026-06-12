-- Add FCM token column to users table for push notifications
BEGIN;

DO $$ BEGIN
  ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Index for faster token lookups (when sending push to specific users)
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;

COMMIT;
