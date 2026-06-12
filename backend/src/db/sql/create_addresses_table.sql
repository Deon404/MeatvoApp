-- Run in pgAdmin Query Tool (or psql) if addresses table is missing.
-- user_id uses BIGINT to match users(id) in this project.

CREATE TABLE IF NOT EXISTS addresses (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  address_line1 TEXT NOT NULL,
  address_line2 TEXT,
  city VARCHAR(100) DEFAULT 'Dhanbad',
  state VARCHAR(100) DEFAULT 'Jharkhand',
  pincode VARCHAR(10),
  landmark TEXT,
  address_type VARCHAR(20) DEFAULT 'HOME',
  latitude DECIMAL(10,8) DEFAULT 23.7957,
  longitude DECIMAL(11,8) DEFAULT 86.4304,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_addresses_default ON addresses(user_id, is_default);
