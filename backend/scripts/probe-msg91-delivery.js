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
    console.log(label, 'OK', r.status, JSON.stringify(r.data));
    return r.data?.request_id;
  } catch (e) {
    console.log(label, 'ERR', e.response?.status, JSON.stringify(e.response?.data || e.message));
    return null;
  }
}

async function checkReport(requestId) {
  if (!requestId) return;
  const endpoints = [
    `https://control.msg91.com/api/v5/report?request_id=${requestId}`,
    `https://control.msg91.com/api/v5/otp/report?request_id=${requestId}`,
    `https://api.msg91.com/api/v5/otp/retry?request_id=${requestId}`,
  ];
  for (const url of endpoints) {
    try {
      const r = await axios.get(url, {
        headers: { authkey: auth },
        timeout: 10000,
      });
      console.log('REPORT', url, JSON.stringify(r.data));
    } catch (e) {
      console.log('REPORT miss', url, e.response?.status || e.message);
    }
  }
}

(async () => {
  const otp = String(Math.floor(1000 + Math.random() * 9000));
  const base = {
    template_id: templateId,
    mobile,
    otp,
    otp_length: Number(process.env.MSG91_OTP_LENGTH || 4),
    otp_expiry: Number(process.env.MSG91_OTP_EXPIRY || 10),
  };

  const rid1 = await trySend('with sender', { ...base, sender: process.env.MSG91_SENDER_ID });
  await checkReport(rid1);

  const rid2 = await trySend('without sender', { ...base });
  await checkReport(rid2);

  if (process.env.MSG91_DLT_TE_ID) {
    const rid3 = await trySend('with DLT_TE_ID', {
      ...base,
      DLT_TE_ID: process.env.MSG91_DLT_TE_ID,
    });
    await checkReport(rid3);
  } else {
    console.log('MSG91_DLT_TE_ID not set — add Jio DLT Content Template ID from DLT portal');
  }
})();
