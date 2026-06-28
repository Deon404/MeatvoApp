#!/usr/bin/env node
/**
 * Promote a user to delivery partner (rider) by phone number.
 *
 * Usage:
 *   node scripts/promote-rider.js 9876543210
 *   node scripts/promote-rider.js --id 42
 *
 * VPS (PM2 bare-metal):
 *   cd /opt/meatvo/backend && node scripts/promote-rider.js 9876543210
 *
 * VPS (Docker):
 *   docker exec meatvo-api node scripts/promote-rider.js 9876543210
 */
require('dotenv').config();
const { query } = require('../src/db/postgres');
const { normalizePhone } = require('../src/modules/auth/auth.validation');

const args = process.argv.slice(2);
let userId = null;
let phoneRaw = null;

for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--id' && args[i + 1]) {
    userId = Number(args[i + 1]);
    i += 1;
  } else if (!args[i].startsWith('-')) {
    phoneRaw = args[i];
  }
}

if (!userId && !phoneRaw) {
  console.error('Usage: node scripts/promote-rider.js <phone>');
  console.error('       node scripts/promote-rider.js --id <user_id>');
  process.exit(1);
}

const phone = phoneRaw ? normalizePhone(phoneRaw) : null;

const ensureDeliveryPartner = async (id) => {
  await query(
    `INSERT INTO delivery_partners (user_id, is_online, approved)
     VALUES ($1, false, true)
     ON CONFLICT (user_id) DO UPDATE
       SET approved = true,
           updated_at = NOW()`,
    [id]
  );
};

const printRider = async (id) => {
  const { rows } = await query(
    `SELECT u.id, u.phone, u.name, u.role,
            dp.id AS partner_id, dp.approved, dp.is_online
     FROM users u
     LEFT JOIN delivery_partners dp ON dp.user_id = u.id
     WHERE u.id = $1`,
    [id]
  );
  return rows[0];
};

(async () => {
  let user;

  if (userId) {
    const { rows } = await query(
      'SELECT id, phone, name, role FROM users WHERE id = $1',
      [userId]
    );
    if (!rows.length) {
      console.error(`User not found for id=${userId}`);
      process.exit(1);
    }
    user = rows[0];
  } else {
    const { rows } = await query(
      'SELECT id, phone, name, role FROM users WHERE phone = $1',
      [phone]
    );
    if (!rows.length) {
      const { rows: created } = await query(
        `INSERT INTO users (phone, role) VALUES ($1, 'delivery')
         RETURNING id, phone, name, role`,
        [phone]
      );
      await ensureDeliveryPartner(created[0].id);
      const rider = await printRider(created[0].id);
      console.log('Created new rider:', rider);
      console.log('Ask the user to log out and log in again to refresh their session.');
      process.exit(0);
    }
    user = rows[0];
  }

  if (user.role === 'delivery') {
    await ensureDeliveryPartner(user.id);
    const rider = await printRider(user.id);
    console.log('Already a rider (ensured delivery_partners row):', rider);
    console.log('Ask the user to log out and log in again if the app still shows customer home.');
    process.exit(0);
  }

  const { rows: updated } = await query(
    `UPDATE users SET role = 'delivery' WHERE id = $1
     RETURNING id, phone, name, role`,
    [user.id]
  );

  await ensureDeliveryPartner(updated[0].id);
  const rider = await printRider(updated[0].id);
  console.log('Promoted to rider:', rider);
  console.log('Ask the user to log out and log in again to refresh their session.');
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
