#!/usr/bin/env node
/**
 * Standalone MSG91 OTP integration test.
 * Usage: node backend/scripts/dev-only/test-otp-debug.js [phone] [otp]
 */
const path = require('path');
const axios = require('axios');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const {
  sendSMS,
  verifySMS,
  formatPhoneForE164,
  formatPhoneForMSG91,
} = require('../../src/utils/msg91');

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
  console.log('  MSG91_TEMPLATE_ID:', templateId ? '(set)' : '(missing)');
  console.log('  MSG91_SENDER_ID:', senderId || '(missing)');
  console.log('  Formatted E.164:', e164);
  console.log('  MSG91 mobile:', msg91Mobile);

  if (!authKey || !templateId || !senderId) {
    console.error('\n❌ Error: Missing MSG91_AUTH_KEY, template id, or MSG91_SENDER_ID in .env');
    process.exit(1);
  }

  const { getMsg91Balance } = require('../../src/utils/msg91');
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

  console.log('\nSending OTP via MSG91...');

  try {
    const sendData = await sendSMS(testPhone, testOtp);
    console.log('Send:', sendData?.type || sendData?.message || 'ok');

    try {
      await verifySMS(testPhone, testOtp);
      console.log('Verify: ok');
    } catch (verifyErr) {
      console.log('Verify: skipped (', verifyErr.message, ')');
    }

    console.log('\nPASSED — MSG91 integration');
    process.exit(0);
  } catch (err) {
    console.error('\nFAILED —', err.message);
    if (err.httpStatus) console.error('  HTTP status:', err.httpStatus);
    process.exit(1);
  }
};

run();
