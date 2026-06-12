#!/usr/bin/env node
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const { getMsg91Balance } = require('../src/utils/msg91');

(async () => {
  const authKey = process.env.MSG91_AUTH_KEY;
  if (!authKey) {
    console.error('❌ MSG91_AUTH_KEY missing in .env');
    process.exit(1);
  }

  try {
    const balance = await getMsg91Balance(authKey, Number(process.env.MSG91_BALANCE_ROUTE_TYPE || 4));
    console.log(`MSG91 balance (route type ${process.env.MSG91_BALANCE_ROUTE_TYPE || 4}): ${balance}`);

    if (balance <= 0) {
      console.error('\n❌ Wallet empty — OTP API may return "success" but SMS will NOT reach the phone.');
      console.error('   Fix: Recharge MSG91 → https://msg91.com (then rerun this script).');
      process.exit(1);
    }

    console.log('\n✅ Balance OK — SMS credits available.');
    process.exit(0);
  } catch (err) {
    console.error('❌ Balance check failed:', err.message);
    process.exit(1);
  }
})();
