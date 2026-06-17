#!/usr/bin/env node
/**
 * Real OTP flow against local backend.
 * Run: node backend/scripts/dev-only/test-otp-real.js
 */

const http = require('http');
const https = require('https');
const readline = require('readline');
const { URL } = require('url');

const BASE = process.env.BACKEND_BASE_URL || 'http://localhost:8080';
const SEND_OTP_URL = `${BASE}/api/auth/send-otp`;
const VERIFY_OTP_URL = `${BASE}/api/auth/verify-otp`;

const RL = readline.createInterface({ input: process.stdin, output: process.stdout });

function ask(question) {
  return new Promise((resolve) => RL.question(question, resolve));
}

function toE164India(raw) {
  const input = String(raw || '').trim();
  if (!input) return '';
  if (input.startsWith('+')) return input;
  let digits = input.replace(/\D/g, '');
  digits = digits.replace(/^0+/, '') || digits;
  if (/^\d{10}$/.test(digits)) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  return input.startsWith('+') ? input : `+${digits}`;
}

function requestJson(urlString, bodyObj) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlString);
    const payload = JSON.stringify(bodyObj);
    const isHttps = u.protocol === 'https:';
    const lib = isHttps ? https : http;
    const port = u.port ? Number(u.port) : isHttps ? 443 : 80;

    const opts = {
      hostname: u.hostname,
      port,
      path: `${u.pathname}${u.search}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'Content-Length': Buffer.byteLength(payload, 'utf8'),
      },
    };

    const req = lib.request(opts, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let json = null;
        try {
          json = raw ? JSON.parse(raw) : null;
        } catch {
          /* keep raw */
        }
        resolve({ statusCode: res.statusCode, raw, json });
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function main() {
  console.log(`Meatvo OTP test — ${BASE}`);

  const phoneInput = await ask('10-digit Indian phone (e.g. 9876543210): ');
  const phoneE164 = toE164India(phoneInput);
  console.log(`Sending OTP to ${phoneE164.slice(0, 4)}****${phoneE164.slice(-2)}`);

  let sendRes;
  try {
    sendRes = await requestJson(SEND_OTP_URL, { phone: phoneE164 });
  } catch (e) {
    console.error('FAILED send-otp:', e.message);
    RL.close();
    process.exit(1);
  }

  if (sendRes.statusCode < 200 || sendRes.statusCode >= 300) {
    console.error('FAILED send-otp HTTP', sendRes.statusCode);
    RL.close();
    process.exit(1);
  }
  console.log('PASSED send-otp — check SMS inbox');

  const otpInput = await ask('Enter OTP from SMS: ');
  const otp = String(otpInput || '').trim();

  let verifyRes;
  try {
    verifyRes = await requestJson(VERIFY_OTP_URL, { phone: phoneE164, otp });
  } catch (e) {
    console.error('FAILED verify-otp:', e.message);
    RL.close();
    process.exit(1);
  }

  const v = verifyRes.json;
  const okHttp = verifyRes.statusCode >= 200 && verifyRes.statusCode < 300;
  const success = okHttp && v && v.success !== false && v.ok !== false && !v.error;

  if (success && v.data) {
    const user = v.data.user || {};
    console.log('PASSED verify-otp — userId:', user.id ?? user.userId ?? '?', 'role:', user.role ?? '?');
    RL.close();
    process.exit(0);
  }

  const msg = v?.error?.message || v?.message || 'verify failed';
  console.error('FAILED verify-otp:', msg);
  RL.close();
  process.exit(1);
}

main().catch((e) => {
  console.error(e.message);
  RL.close();
  process.exit(1);
});
