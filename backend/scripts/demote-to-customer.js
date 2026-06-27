#!/usr/bin/env node
/**
 * Demote a user to customer by phone number.
 * Usage: node scripts/demote-to-customer.js 9110159550
 */
require('dotenv').config();
const { query } = require('../src/db/postgres');
const { normalizePhone } = require('../src/modules/auth/auth.validation');

const phoneRaw = process.argv[2];
if (!phoneRaw) {
  console.error('Usage: node scripts/demote-to-customer.js <phone>');
  process.exit(1);
}

const phone = normalizePhone(phoneRaw);

(async () => {
  const { rows: existing } = await query(
    'SELECT id, phone, name, role FROM users WHERE phone = $1',
    [phone]
  );

  if (!existing.length) {
    console.error('User not found:', phone);
    process.exit(1);
  }

  const user = existing[0];
  if (user.role === 'customer') {
    console.log('Already customer:', user);
    process.exit(0);
  }

  const { rows: updated } = await query(
    `UPDATE users SET role = 'customer' WHERE id = $1
     RETURNING id, phone, name, role`,
    [user.id]
  );
  console.log('Demoted to customer:', updated[0]);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
