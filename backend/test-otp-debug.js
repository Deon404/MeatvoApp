#!/usr/bin/env node
/**
 * Standalone MSG91 OTP integration test.
 * Usage: node test-otp-debug.js [phone] [otp]
 * Example: node test-otp-debug.js 7061036957 1234
 */
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const {
  sendSMS,
  verifySMS,
  formatPhoneForE164,
  formatPhoneForMSG91,
} = require('./src/utils/msg91');

const maskAuthKey = (key) => {
  const s = String(key || '');
  if (s.length <= 8) return '****';
  return `${s.slice(0, 4)}${'*'.repeat(Math.max(4, s.length - 8))}${s.slice(-4)}`;
};

const testPhone = process.argv[2] || process.env.OTP_TEST_PHONE;
const testOtp = process.argv[3] || process.env.OTP_TEST_OTP;

const run = async () => {
  console.log('--- MSG91 OTP debug test ---\n');

  const e164 = formatPhoneForE164(testPhone);
  const msg91Mobile = formatPhoneForMSG91(testPhone);
  const authKey = process.env.MSG91_AUTH_KEY;
  const templateId = process.env.MSG91_OTP_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID;
  const senderId = process.env.MSG91_SENDER_ID;
  const url = process.env.MSG91_OTP_URL || 'https://control.msg91.com/api/v5/otp';

  console.log('Env check:');
  console.log('  MSG91_AUTH_KEY:', authKey ? maskAuthKey(authKey) : '(missing)');
  console.log('  MSG91_TEMPLATE_ID:', templateId || '(missing)');
  console.log('  MSG91_SENDER_ID:', senderId || '(missing)');
  console.log('  MSG91_OTP_URL:', url);
  console.log('  Formatted E.164:', e164);
  console.log('  MSG91 mobile:', msg91Mobile);
  console.log('  Test OTP length:', String(testOtp).length);

  if (!authKey || !templateId || !senderId) {
    console.error('\n❌ Error: Missing MSG91_AUTH_KEY, template id, or MSG91_SENDER_ID in .env');
    process.exit(1);
  }

  const { getMsg91Balance } = require('./src/utils/msg91');
  try {
    const balance = await getMsg91Balance(authKey);
    console.log('  MSG91 wallet balance:', balance);
    if (balance <= 0) {
      console.error('\n❌ MSG91 wallet balance is ZERO — recharge credits; API "success" does not deliver SMS.');
      process.exit(1);
    }
  } catch (balErr) {
    console.warn('  Balance check warning:', balErr.message);
  }

  const requestHeaders = {
    authkey: maskAuthKey(authKey),
    'Content-Type': 'application/json',
  };
  const requestBody = {
    template_id: templateId,
    mobile: msg91Mobile,
    otp: String(testOtp),
    sender: senderId,
    short_url: 0,
    flash_sms: 0,
  };

  console.log('\nRequest (authkey masked):');
  console.log('  POST', url);
  console.log('  headers:', JSON.stringify(requestHeaders, null, 2));
  console.log('  body:', JSON.stringify(requestBody, null, 2));

  try {
    const sendData = await sendSMS(testPhone, testOtp);
    console.log('\nSend response:', JSON.stringify(sendData, null, 2));

    console.log('\nVerify request (mock OTP on MSG91 side — may fail if OTP not active):');
    try {
      const verifyData = await verifySMS(testPhone, testOtp);
      console.log('Verify response:', JSON.stringify(verifyData, null, 2));
    } catch (verifyErr) {
      console.log(
        'Verify note:',
        verifyErr.response?.data || verifyErr.message,
        '(expected if OTP already consumed or only app-side verify is used)'
      );
    }

    console.log('\n✅ MSG91 integration working');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ Error:', err.message);
    if (err.httpStatus) console.error('  HTTP status:', err.httpStatus);
    if (err.msg91) console.error('  MSG91 body:', JSON.stringify(err.msg91, null, 2));
    if (err.cause?.response?.data) {
      console.error('  Raw API:', JSON.stringify(err.cause.response.data, null, 2));
    }
    process.exit(1);
  }
};

run();
