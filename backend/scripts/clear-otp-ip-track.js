#!/usr/bin/env node
/**
 * Clear multi-IP OTP block for a phone number (Redis key ips:{phone}).
 * Usage: node scripts/clear-otp-ip-track.js +917061036957
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const redis = require('../src/db/redis');
const { normalizePhone } = require('../src/modules/auth/auth.validation');

async function main() {
  const raw = process.argv[2];
  const phone = normalizePhone(raw);
  if (!phone) {
    console.error('Usage: node scripts/clear-otp-ip-track.js +91XXXXXXXXXX');
    process.exit(1);
  }

  const key = `ips:${phone}`;
  const deleted = await redis.del(key);
  console.log(deleted ? `Cleared ${key}` : `No block found for ${key}`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
