#!/usr/bin/env node
/**
 * Real OTP flow against local backend — Node.js built-ins only (http, https, readline, fs, path).
 * Run from backend folder: node test-otp-real.js
 */

const http = require('http');
const https = require('https');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const BASE = 'http://localhost:8080';
const SEND_OTP_URL = `${BASE}/api/auth/send-otp`;
const VERIFY_OTP_URL = `${BASE}/api/auth/verify-otp`;

const RL = readline.createInterface({ input: process.stdin, output: process.stdout });

function ask(question) {
  return new Promise((resolve) => RL.question(question, resolve));
}

/** Mirror backend auth.validation.js normalizePhone + E.164 for India testing */
function toE164India(raw) {
  const input = String(raw || '').trim();
  if (!input) return '';
  if (input.startsWith('+')) return input;

  let digits = input.replace(/\D/g, '');
  digits = digits.replace(/^0+/, '') || digits;

  const defaultCc = '+91';
  if (/^\d{10}$/.test(digits)) return `${defaultCc}${digits}`;
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
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          raw,
          json,
        });
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function printSection(title) {
  console.log('');
  console.log(`=== ${title} ===`);
}

function safeStringify(obj) {
  try {
    return JSON.stringify(obj, null, 2);
  } catch {
    return String(obj);
  }
}

function readDartFilesAndSummarize() {
  const repoRoot = path.join(__dirname, '..');
  const envPath = path.join(repoRoot, 'old_meatvo', 'lib', 'config', 'env_config.dart');
  const authPath = path.join(repoRoot, 'old_meatvo', 'lib', 'services', 'auth_service.dart');
  const storagePath = path.join(repoRoot, 'old_meatvo', 'lib', 'services', 'storage_service.dart');

  printSection('FRONTEND CONFIG CHECK — files read');
  console.log(`env_config.dart → ${envPath}`);
  console.log(`auth_service.dart → ${authPath}`);
  console.log(`(import chain) storage_service.dart → ${storagePath}`);

  let envSrc = '';
  let authSrc = '';
  let storageSrc = '';
  try {
    envSrc = fs.readFileSync(envPath, 'utf8');
  } catch (e) {
    console.log(`ERROR reading env_config.dart: ${e.message}`);
  }
  try {
    authSrc = fs.readFileSync(authPath, 'utf8');
  } catch (e) {
    console.log(`ERROR reading auth_service.dart: ${e.message}`);
  }
  try {
    storageSrc = fs.readFileSync(storagePath, 'utf8');
  } catch (e) {
    console.log(`WARN reading storage_service.dart: ${e.message}`);
  }

  if (envSrc) {
    printSection('EXCERPT: env_config.dart (backend root)');
    const lines = envSrc.split(/\r?\n/);
    const sliceStart = Math.max(0, lines.findIndex((l) => l.includes('backendBaseUrl')) - 2);
    const excerpt = lines.slice(sliceStart, sliceStart + 12).join('\n');
    console.log(excerpt || '(could not locate backendBaseUrl block)');
  }

  if (authSrc) {
    printSection('EXCERPT: auth_service.dart (OTP + storage calls)');
    const lines = authSrc.split(/\r?\n/);
    const idx = lines.findIndex((l) => l.includes('Future<UserModel> verifyOtp'));
    const start = idx >= 0 ? Math.max(0, idx - 3) : 0;
    const excerpt = lines.slice(start, start + 45).join('\n');
    console.log(excerpt);
  }

  if (storageSrc) {
    printSection('EXCERPT: storage_service.dart (AuthService dependency — token keys)');
    const lines = storageSrc.split(/\r?\n/);
    const start = Math.max(0, lines.findIndex((l) => l.includes('FlutterSecureStorage')) - 2);
    const excerpt = lines.slice(start, start + 40).join('\n');
    console.log(excerpt);
  }

  printSection('FRONTEND CONFIG — extracted answers');

  let baseUrlValue = '(not found)';
  const mConst = envSrc.match(/static\s+const\s+String\s+backendBaseUrl\s*=\s*['"]([^'"]+)['"]/);
  if (mConst) baseUrlValue = mConst[1];

  console.log(`Current backend root (EnvConfig.backendBaseUrl): ${baseUrlValue}`);
  console.log(
    'Effective HTTP API base for Dio: `${backendRootUrl}/api` — EnvConfig.backendRootUrl maps to same const (see api_config.dart kBaseUrl).'
      .replace('${backendRootUrl}', baseUrlValue)
  );

  console.log(
    'Access token storage: AuthService calls `_storage.saveTokens` after verify (auth_service.dart).'
  );
  if (storageSrc) {
    const isSecure = storageSrc.includes('FlutterSecureStorage');
    const kAccess = storageSrc.match(/_kAccessToken\s*=\s*['"]([^'"]+)['"]/);
    const kRefresh = storageSrc.match(/_kRefreshToken\s*=\s*['"]([^'"]+)['"]/);
    console.log(
      `  → Implementation: ${isSecure ? 'FlutterSecureStorage (encryptedSharedPreferences on Android)' : 'see storage_service.dart'}`
    );
    console.log(`  → access_token key: ${kAccess ? kAccess[1] : '(parse failed)'}`);
    console.log(`  → refresh_token key: ${kRefresh ? kRefresh[1] : '(parse failed)'}`);
  } else {
    console.log('  → (storage_service.dart missing — cannot print key names)');
  }

  console.log(
    'Authorization header: not set in auth_service.dart; ApiService attaches `Authorization: Bearer <access_token>` in Dio interceptor (lib/services/api_service.dart `onRequest`).'
  );

  console.log(
    'After OTP verify (UI layer — login_screen.dart `_verifyOTP`): role `rider` → RiderDashboardScreen; role `admin` → AdminDashboardScreen; baaki → MyHomePage (pushAndRemoveUntil, routes clear).'
  );

  printSection('DONE');
}

async function main() {
  console.log('Meatvo — real OTP test (localhost:8080). Ctrl+C to abort.');

  printSection('1) SEND OTP');
  const phoneInput = await ask('Apna 10-digit Indian phone number enter karein (e.g. 9876543210): ');
  const phoneE164 = toE164India(phoneInput);
  console.log(`Formatted E.164: ${phoneE164}`);
  console.log(`POST ${SEND_OTP_URL}`);
  console.log(`Body: ${safeStringify({ phone: phoneE164 })}`);

  let sendRes;
  try {
    sendRes = await requestJson(SEND_OTP_URL, { phone: phoneE164 });
  } catch (e) {
    console.error('HTTP error (send-otp):', e.message);
    RL.close();
    process.exit(1);
  }

  console.log(`HTTP status: ${sendRes.statusCode}`);
  console.log('Exact response body (raw):');
  console.log(sendRes.raw);

  if (sendRes.json && sendRes.json.data && sendRes.json.data.devOTP !== undefined) {
    console.log('');
    console.log(`>>> devOTP (development only): ${sendRes.json.data.devOTP}`);
  }

  console.log('');
  console.log('Real SMS aapke phone par aana chahiye — inbox check karein (MSG91).');

  printSection('2) VERIFY OTP');
  const otpInput = await ask('SMS mein jo 4-digit OTP aaya hai, yahan type karein: ');
  const otp = String(otpInput || '').trim();

  console.log(`POST ${VERIFY_OTP_URL}`);
  console.log(`Body: ${safeStringify({ phone: phoneE164, otp })}`);

  let verifyRes;
  try {
    verifyRes = await requestJson(VERIFY_OTP_URL, { phone: phoneE164, otp });
  } catch (e) {
    console.error('HTTP error (verify-otp):', e.message);
    RL.close();
    process.exit(1);
  }

  console.log(`HTTP status: ${verifyRes.statusCode}`);
  console.log('Exact response body (raw):');
  console.log(verifyRes.raw);

  const v = verifyRes.json;
  const okHttp = verifyRes.statusCode >= 200 && verifyRes.statusCode < 300;
  const success = okHttp && v && v.success !== false && v.ok !== false && !v.error;

  if (success && v.data) {
    const d = v.data;
    const user = d.user || {};
    const uid = user.id ?? user.userId ?? '(missing in payload)';
    const role = user.role ?? '(missing)';
    const accessToken = d.accessToken || d.token || '';
    const prefix = typeof accessToken === 'string' ? accessToken.slice(0, 40) : '';

    printSection('VERIFY SUCCESS — summary');
    console.log(`userId: ${uid}`);
    console.log(`role: ${role}`);
    console.log(`accessToken (first 40 chars): ${prefix}${accessToken.length > 40 ? '…' : ''}`);

    RL.close();
    readDartFilesAndSummarize();
    process.exit(0);
  }

  printSection('VERIFY FAILED — reason');
  if (v && v.error && v.error.message) {
    console.log(`error.message: ${v.error.message}`);
  }
  if (v && v.message) {
    console.log(`message: ${v.message}`);
  }
  if (v && v.data && v.data.requiresMFA) {
    console.log('MFA required for this user — body needs mfaToken (6 digits) per verify-otp schema.');
  }
  if (!v) {
    console.log('Response was not valid JSON; see raw body above.');
  }

  RL.close();
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  RL.close();
  process.exit(1);
});
