#!/usr/bin/env node
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const axios = require('axios');
const { Pool } = require('pg');

const TEST_PHONE = process.env.OTP_TEST_PHONE;
const BASE_URL = process.env.BACKEND_BASE_URL || `http://localhost:${process.env.PORT || 8080}`;

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'meatvo',
  connectionTimeoutMillis: 7000,
});

const printStep = (title) => console.log(`\n=== ${title} ===`);
const printPass = (message) => console.log(`[✓] ${message}`);
const printFail = (message) => console.log(`[x] ${message}`);

async function checkUserRecord(phone) {
  const result = await pool.query(
    'SELECT id, phone, role, created_at FROM users WHERE RIGHT(phone, 10) = RIGHT($1, 10) ORDER BY id DESC LIMIT 1',
    [phone]
  );
  return result.rows?.[0] || null;
}

async function checkLatestOtpLog(phone) {
  const result = await pool.query(
    `SELECT id, phone, verified, created_at, expires_at
     FROM otp_logs
     WHERE RIGHT(phone, 10) = RIGHT($1, 10)
       AND created_at > NOW() - INTERVAL '15 minutes'
     ORDER BY created_at DESC
     LIMIT 1`,
    [phone]
  );
  return result.rows?.[0] || null;
}

async function testSendOtp() {
  printStep('1) POST /api/auth/send-otp');
  const response = await axios.post(`${BASE_URL}/api/auth/send-otp`, { phone: TEST_PHONE }, { timeout: 12000 });
  const payload = response.data?.data || {};

  printPass(`OTP send response received (status=${response.status})`);
  const otpLog = await checkLatestOtpLog(TEST_PHONE);
  if (!otpLog) {
    throw new Error('OTP log not found in otp_logs table after send-otp');
  }
  printPass(`OTP log created (id=${otpLog.id}, verified=${otpLog.verified})`);

  const devOtp = payload.devOTP;
  if (!devOtp) {
    throw new Error(
      'devOTP not returned. Set OTP_LOG_TO_CONSOLE=true in non-production for automated verify test.'
    );
  }
  printPass('Development OTP captured from response');

  return String(devOtp);
}

async function testVerifyOtp(otp) {
  printStep('2) POST /api/auth/verify-otp');
  const response = await axios.post(
    `${BASE_URL}/api/auth/verify-otp`,
    { phone: TEST_PHONE, otp: String(otp) },
    { timeout: 12000 }
  );

  const payload = response.data?.data || {};
  const token = payload.token || payload.accessToken;
  if (!token) {
    throw new Error('JWT token missing in verify-otp response');
  }
  printPass('JWT token returned from verify-otp');

  const user = await checkUserRecord(TEST_PHONE);
  if (!user) {
    throw new Error('User record missing in users table after verify-otp');
  }
  printPass(`User exists/updated in DB (id=${user.id}, role=${user.role})`);

  return token;
}

async function testAuthHealth() {
  printStep('3) GET /api/auth/health');
  const response = await axios.get(`${BASE_URL}/api/auth/health`, { timeout: 7000 });
  const body = response.data || {};
  const isHealthy = body.status === 'OK' && body.db === 'connected';
  if (!isHealthy) {
    throw new Error(`Unexpected health payload: ${JSON.stringify(body)}`);
  }
  printPass('Auth health payload is valid: { status: "OK", db: "connected" }');
}

async function main() {
  console.log(`Testing OTP flow for phone ${TEST_PHONE} against ${BASE_URL}`);

  try {
    const otp = await testSendOtp();
    await testVerifyOtp(otp);
    await testAuthHealth();
    console.log('\nAll OTP flow tests passed.');
    process.exitCode = 0;
  } catch (error) {
    const status = error.response?.status;
    const message = error.message || error.code || 'Unknown failure';
    printFail(status ? `HTTP ${status}: ${message}` : message);
    process.exitCode = 1;
  } finally {
    await pool.end().catch(() => {});
  }
}

main().catch(async (error) => {
  const status = error.response?.status;
  const message = error.message || error.code || 'Unknown failure';
  printFail(status ? `HTTP ${status}: ${message}` : message);
  await pool.end().catch(() => {});
  process.exit(1);
});
