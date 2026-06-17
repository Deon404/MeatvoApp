#!/usr/bin/env node
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const axios = require('axios');
const { query, pool } = require('../../src/db/postgres');

const BASE_URL = `http://localhost:${process.env.PORT || 8080}`;
const TEST_PHONE = '+919555555560';

const logStep = (n, message) => console.log(`\n=== Step ${n}: ${message} ===`);

async function cleanupOrder(orderId) {
  if (!orderId) return;
  logStep(7, 'Cleanup — delete test order');
  await query('DELETE FROM orders WHERE id = $1', [orderId]);
  console.log(`Deleted test order id=${orderId}`);
}

async function main() {
  let orderId = null;

  try {
    logStep(1, 'Send OTP');
    const sendOtpRes = await axios.post(`${BASE_URL}/api/auth/send-otp`, {
      phone: TEST_PHONE,
    });
    const devOTP = sendOtpRes.data?.data?.devOTP;
    console.log('send-otp response:', JSON.stringify(sendOtpRes.data, null, 2));
    if (!devOTP) {
      throw new Error('devOTP missing from send-otp response (set OTP_LOG_TO_CONSOLE=true in dev)');
    }
    console.log('devOTP:', devOTP);

    logStep(2, 'Verify OTP and get JWT');
    const verifyOtpRes = await axios.post(`${BASE_URL}/api/auth/verify-otp`, {
      phone: TEST_PHONE,
      otp: String(devOTP),
    });
    const accessToken =
      verifyOtpRes.data?.data?.accessToken || verifyOtpRes.data?.data?.token;
    if (!accessToken) {
      throw new Error('accessToken missing from verify-otp response');
    }
    console.log('accessToken received (truncated):', `${accessToken.slice(0, 24)}...`);

    logStep(3, 'Get user ID from DB');
    const userResult = await query('SELECT id FROM users WHERE phone = $1', [TEST_PHONE]);
    if (userResult.rows.length === 0) {
      throw new Error(`No user found for phone ${TEST_PHONE}`);
    }
    const userId = userResult.rows[0].id;
    console.log('userId:', userId);

    logStep(4, 'Seed test order in DB');
    const address = {
      line1: 'Test address',
      city: 'Bokaro',
      pincode: '827001',
    };
    const orderResult = await query(
      `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode)
       VALUES ($1, 'PLACED', 199.00, $2, 'ONLINE')
       RETURNING id`,
      [userId, address]
    );
    orderId = orderResult.rows[0].id;
    console.log('orderId:', orderId);

    logStep(5, 'Cashfree initiate');
    let initiateRes;
    try {
      initiateRes = await axios.post(
        `${BASE_URL}/api/payments/cashfree/initiate`,
        { orderId },
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
        }
      );
    } catch (axiosError) {
      if (axiosError.response?.data) {
        console.log('cashfree/initiate error response:', JSON.stringify(axiosError.response.data, null, 2));
      }
      throw axiosError;
    }
    console.log('cashfree/initiate response:', JSON.stringify(initiateRes.data, null, 2));

    logStep(6, 'Result');
    const paymentSessionId = initiateRes.data?.data?.payment_session_id;
    if (paymentSessionId) {
      console.log('✅ CASHFREE INTEGRATION WORKING');
      console.log('payment_session_id:', paymentSessionId);
    } else {
      console.log('❌ FAILED: payment_session_id missing in response');
      process.exitCode = 1;
    }
  } catch (error) {
    const details =
      error.response?.data?.error?.message ||
      error.response?.data?.message ||
      JSON.stringify(error.response?.data) ||
      error.message;
    console.log(`❌ FAILED: ${details}`);
    process.exitCode = 1;
  } finally {
    try {
      await cleanupOrder(orderId);
    } catch (cleanupError) {
      console.error('Cleanup failed:', cleanupError.message);
    }
    await pool.end().catch(() => {});
  }
}

main();
