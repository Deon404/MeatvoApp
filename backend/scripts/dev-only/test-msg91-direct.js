#!/usr/bin/env node
/**
 * Direct MSG91 OTP API probe (dev only).
 * Run: node backend/scripts/dev-only/test-msg91-direct.js
 */
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const MSG91_URL = 'https://api.msg91.com/api/v5/otp';
const TEST_MOBILE = process.env.OTP_TEST_MOBILE;
const TEST_OTP = process.env.OTP_TEST_OTP;

const maskMiddle = (value) => {
  const str = String(value || '');
  if (!str) return '(missing)';
  if (str.length <= 8) return '****';
  return `${str.slice(0, 4)}****${str.slice(-4)}`;
};

async function main() {
  const authKey = process.env.MSG91_AUTH_KEY;
  const templateId = process.env.MSG91_OTP_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID;

  if (!authKey || !templateId || !TEST_MOBILE || !TEST_OTP) {
    console.error('FAILED — set MSG91_AUTH_KEY, template id, OTP_TEST_MOBILE, OTP_TEST_OTP in backend/.env');
    process.exit(1);
  }

  console.log('MSG91 direct probe — authkey:', maskMiddle(authKey), 'mobile:', TEST_MOBILE);

  const response = await axios({
    method: 'POST',
    url: MSG91_URL,
    headers: { authkey: authKey, 'Content-Type': 'application/json' },
    data: {
      template_id: templateId,
      mobile: TEST_MOBILE,
      otp: TEST_OTP,
    },
    timeout: Number(process.env.SMS_HTTP_TIMEOUT_MS || 10000),
    validateStatus: () => true,
  });

  if (response.status >= 200 && response.status < 300) {
    console.log('PASSED — HTTP', response.status, response.data?.type || response.data?.message || '');
    process.exit(0);
  }

  console.error('FAILED — HTTP', response.status, JSON.stringify(response.data));
  process.exit(1);
}

main().catch((error) => {
  console.error('FAILED —', error.message);
  process.exit(1);
});
