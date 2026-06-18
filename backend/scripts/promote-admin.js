#!/usr/bin/env node
/**
 * Promote a user to admin by phone number.
 * Usage: node scripts/promote-admin.js 7061036957
 */
require('dotenv').config();
const { query } = require('../src/db/postgres');
const { normalizePhone } = require('../src/modules/auth/auth.validation');

const phoneRaw = process.argv[2];
if (!phoneRaw) {
  console.error('Usage: node scripts/promote-admin.js <phone>');
  process.exit(1);
}

const phone = normalizePhone(phoneRaw);

(async () => {
  const { rows: existing } = await query(
    'SELECT id, phone, name, role FROM users WHERE phone = $1',
    [phone]
  );

  if (!existing.length) {
    const { rows: created } = await query(
      `INSERT INTO users (phone, role) VALUES ($1, 'admin')
       RETURNING id, phone, name, role`,
      [phone]
    );
    console.log('Created new admin user:', created[0]);
    process.exit(0);
  }

  const user = existing[0];
  if (user.role === 'admin') {
    console.log('Already admin:', user);
    process.exit(0);
  }

  const { rows: updated } = await query(
    `UPDATE users SET role = 'admin' WHERE id = $1
     RETURNING id, phone, name, role`,
    [user.id]
  );
  console.log('Promoted to admin:', updated[0]);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
