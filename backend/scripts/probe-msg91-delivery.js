#!/usr/bin/env node
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const auth = process.env.MSG91_AUTH_KEY;
const mobile = process.env.OTP_TEST_MOBILE;
const templateId = process.env.MSG91_OTP_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID;

async function trySend(label, data) {
  try {
    const r = await axios.post('https://control.msg91.com/api/v5/otp', data, {
      headers: { authkey: auth, 'Content-Type': 'application/json' },
      timeout: 20000,
    });
    console.log(`${label}: PASS HTTP ${r.status}`);
    return r.data?.request_id;
  } catch (e) {
    console.log(`${label}: FAIL HTTP ${e.response?.status || 'err'}`);
    return null;
  }
}

(async () => {
  if (!auth || !mobile || !templateId) {
    console.error('FAILED — set MSG91_AUTH_KEY, OTP_TEST_MOBILE, template id in backend/.env');
    process.exit(1);
  }

  const otp = String(Math.floor(1000 + Math.random() * 9000));
  const base = {
    template_id: templateId,
    mobile,
    otp,
    otp_length: Number(process.env.MSG91_OTP_LENGTH || 4),
    otp_expiry: Number(process.env.MSG91_OTP_EXPIRY || 10),
  };

  await trySend('with sender', { ...base, sender: process.env.MSG91_SENDER_ID });
  await trySend('without sender', { ...base });

  if (process.env.MSG91_DLT_TE_ID) {
    await trySend('with DLT_TE_ID', { ...base, DLT_TE_ID: process.env.MSG91_DLT_TE_ID });
  } else {
    console.log('MSG91_DLT_TE_ID not set — skip DLT probe');
  }
})();
