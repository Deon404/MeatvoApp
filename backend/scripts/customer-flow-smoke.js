#!/usr/bin/env node
/**
 * Customer flow API smoke test — OTP → browse → cart → COD order.
 *
 * Usage:
 *   node scripts/customer-flow-smoke.js [otp]
 *   OTP=1234 node scripts/customer-flow-smoke.js
 *
 * Steps:
 *   1. POST /api/auth/send-otp
 *   2. POST /api/auth/verify-otp (OTP from arg, env, or dev-login bypass)
 *   3. GET  /api/users/me
 *   4. GET/POST /api/addresses
 *   5. GET  /api/products → POST /api/cart
 *   6. POST /api/store/estimate-delivery (express ETA preview)
 *   7. POST /api/orders (COD)
 *   8. GET  /api/orders/:id
 */

const axios = require('axios');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const PORT = Number(process.env.PORT || 8080);
const HOST_RAW = process.env.HOST || '127.0.0.1';
const HOST = HOST_RAW === '0.0.0.0' ? '127.0.0.1' : HOST_RAW;
const BASE =
  process.env.SMOKE_BASE_URL ||
  process.env.BACKEND_ROOT_URL ||
  `http://${HOST}:${PORT}`;
const PHONE = process.env.SMOKE_PHONE || '+919000000001';
let OTP = process.argv[2] || process.env.SMOKE_OTP || process.env.OTP;

let pass = 0;
let fail = 0;
let skip = 0;

function log(status, label, detail = '') {
  const colors = { PASS: '\x1b[32m', FAIL: '\x1b[31m', SKIP: '\x1b[33m', INFO: '\x1b[36m' };
  const c = colors[status] || '';
  const suffix = detail ? ` — ${detail}` : '';
  console.log(`${c}[${status}]\x1b[0m ${label}${suffix}`);
  if (status === 'PASS') pass += 1;
  else if (status === 'FAIL') fail += 1;
  else if (status === 'SKIP') skip += 1;
}

function unwrap(res) {
  const body = res.data;
  if (body && typeof body === 'object' && ('ok' in body || 'success' in body)) {
    if (body.ok === false || body.success === false) {
      throw new Error(body.message || 'Request failed');
    }
    return body.data ?? body;
  }
  return body;
}

async function tryDevLogin() {
  const enabled =
    process.env.NODE_ENV !== 'production' &&
    String(process.env.DEV_AUTH_BYPASS_ENABLED || '').toLowerCase() === 'true';
  const secret = process.env.DEV_AUTH_BYPASS_SECRET;
  if (!enabled || !secret) return null;

  const res = await axios.post(
    `${BASE}/api/auth/dev-login`,
    { phone: PHONE, secret, role: 'customer' },
    { validateStatus: () => true }
  );
  if (res.status !== 200) return null;
  const data = unwrap(res);
  return data.accessToken || data.token;
}

async function authenticate() {
  const devToken = await tryDevLogin();
  if (devToken) {
    log('PASS', 'auth/dev-login', 'dev bypass token issued');
    return devToken;
  }

  log('INFO', 'auth/send-otp', PHONE);
  const sendRes = await axios.post(
    `${BASE}/api/auth/send-otp`,
    { phone: PHONE },
    { validateStatus: () => true }
  );

  if (sendRes.status === 429 && sendRes.data?.data?.remainingSeconds) {
    log('INFO', 'auth/send-otp', 'OTP already sent — use existing OTP');
  } else if (sendRes.status >= 400) {
    const msg = sendRes.data?.message || `send-otp HTTP ${sendRes.status}`;
    if (msg.includes('Service temporarily unavailable')) {
      throw new Error(
        `${msg} — Redis may be down while REDIS_URL is set. ` +
          'Run: docker compose up -d redis  OR  restart backend after pulling latest dev fallback fixes.'
      );
    }
    throw new Error(msg);
  } else {
    log('PASS', 'auth/send-otp');
  }

  const sendData = sendRes.data?.data || {};
  if (sendData.devOTP) {
    OTP = String(sendData.devOTP);
  }

  if (!OTP) {
    log('SKIP', 'auth/verify-otp', 'Pass OTP as arg: node scripts/customer-flow-smoke.js 1234');
    log('INFO', 'hint', 'In development, send-otp returns data.devOTP when NODE_ENV!=production');
    return null;
  }

  const verifyRes = await axios.post(
    `${BASE}/api/auth/verify-otp`,
    { phone: PHONE, otp: String(OTP) },
    { validateStatus: () => true }
  );
  if (verifyRes.status >= 400) {
    throw new Error(verifyRes.data?.message || `verify-otp HTTP ${verifyRes.status}`);
  }
  const data = unwrap(verifyRes);
  const token = data.accessToken || data.token;
  if (!token) throw new Error('No access token in verify response');
  log('PASS', 'auth/verify-otp');
  return token;
}

function authHeaders(token) {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

async function ensureAddress(token) {
  const listRes = await axios.get(`${BASE}/api/addresses`, {
    headers: authHeaders(token),
    validateStatus: () => true,
  });
  if (listRes.status >= 400) {
    throw new Error(listRes.data?.message || `addresses GET ${listRes.status}`);
  }
  const list = unwrap(listRes);
  const addresses = Array.isArray(list) ? list : list?.addresses || [];
  if (addresses.length > 0) {
    const addr = addresses.find((a) => a.is_default || a.isDefault) || addresses[0];
    log('PASS', 'addresses', `using existing id=${addr.id}`);
    return addr;
  }

  const body = {
    label: 'home',
    addressLine1: '123 Smoke Test Lane, Koramangala',
    city: 'Bengaluru',
    state: 'Karnataka',
    pincode: '560034',
    lat: 12.9352,
    lng: 77.6245,
    isDefault: true,
  };
  const createRes = await axios.post(`${BASE}/api/addresses`, body, {
    headers: authHeaders(token),
    validateStatus: () => true,
  });
  if (createRes.status >= 400) {
    throw new Error(createRes.data?.message || `addresses POST ${createRes.status}`);
  }
  const addr = unwrap(createRes);
  log('PASS', 'addresses/create', `id=${addr.id}`);
  return addr;
}

async function addProductToCart(token) {
  const prodRes = await axios.get(`${BASE}/api/products?limit=5&inStock=true`, {
    validateStatus: () => true,
  });
  if (prodRes.status >= 400) throw new Error(`products GET ${prodRes.status}`);
  const productsPayload = unwrap(prodRes);
  const products = Array.isArray(productsPayload)
    ? productsPayload
    : productsPayload?.products || productsPayload?.items || [];
  const product = products.find((p) => p.is_active !== false && Number(p.stock || 0) > 0) || products[0];
  if (!product) throw new Error('No products available for cart smoke test');

  const cartRes = await axios.post(
    `${BASE}/api/cart`,
    { productId: String(product.id), quantity: 1 },
    { headers: authHeaders(token), validateStatus: () => true }
  );
  if (cartRes.status >= 400) {
    throw new Error(cartRes.data?.message || `cart POST ${cartRes.status}`);
  }
  log('PASS', 'cart/add', `productId=${product.id} name=${product.name || product.title || '?'}`);
}

async function estimateExpressDelivery(token, address) {
  const lat = address.lat ?? address.latitude;
  const lng = address.lng ?? address.longitude;
  const res = await axios.post(
    `${BASE}/api/store/estimate-delivery`,
    { lat, lng, items: [{ quantity: 1 }] },
    { headers: authHeaders(token), validateStatus: () => true }
  );
  if (res.status >= 400) {
    throw new Error(res.data?.message || `estimate-delivery POST ${res.status}`);
  }
  const payload = unwrap(res);
  log('PASS', 'store/estimate-delivery', `etaMinutes=${payload.etaMinutes || payload.eta_minutes}`);
  return payload;
}

async function placeCodOrder(token, address) {
  const deliveryAddress = [
    address.address_line1 || address.addressLine1,
    address.city,
    address.pincode,
  ]
    .filter(Boolean)
    .join(', ');

  const body = {
    addressId: address.id,
    deliveryAddress,
    lat: address.lat ?? address.latitude,
    lng: address.lng ?? address.longitude,
    paymentMethod: 'COD',
  };

  const orderRes = await axios.post(`${BASE}/api/orders`, body, {
    headers: authHeaders(token),
    validateStatus: () => true,
  });
  if (orderRes.status >= 400) {
    throw new Error(orderRes.data?.message || `orders POST ${orderRes.status}`);
  }
  const payload = unwrap(orderRes);
  const order = payload.order || payload;
  const orderId = order.id || payload.orderId;
  log('PASS', 'orders/create COD', `id=${orderId} status=${order.status}`);
  return orderId;
}

async function fetchOrder(token, orderId) {
  if (!orderId) {
    log('SKIP', 'orders/detail', 'no order id returned');
    return;
  }
  const res = await axios.get(`${BASE}/api/orders/${orderId}`, {
    headers: authHeaders(token),
    validateStatus: () => true,
  });
  if (res.status >= 400) {
    throw new Error(res.data?.message || `orders GET ${res.status}`);
  }
  const payload = unwrap(res);
  const order = payload.order || payload;
  log(
    'PASS',
    'orders/detail',
    `status=${order.status} total=${order.total_price || order.total_amount || order.final_amount}`
  );
}

async function main() {
  console.log('\n=== Meatvo Customer Flow Smoke Test ===');
  console.log(`Target: ${BASE}`);
  console.log(`Phone:  ${PHONE}\n`);

  try {
    const health = await axios.get(`${BASE}/health`, { validateStatus: () => true, timeout: 8000 });
    if (health.status !== 200) {
      throw new Error(
        `Backend not reachable at ${BASE} (HTTP ${health.status}). Start it with: npm run dev`
      );
    }
    log('PASS', 'health', BASE);

    const token = await authenticate();
    if (!token) {
      console.log('\n--- Summary ---');
      console.log(`PASS: ${pass}  FAIL: ${fail}  SKIP: ${skip}`);
      console.log('\nRe-run with OTP: node scripts/customer-flow-smoke.js <otp>\n');
      process.exit(skip > 0 && fail === 0 ? 0 : 1);
    }

    const meRes = await axios.get(`${BASE}/api/users/me`, {
      headers: authHeaders(token),
      validateStatus: () => true,
    });
    if (meRes.status >= 400) throw new Error(`users/me ${meRes.status}`);
    const me = unwrap(meRes);
    log('PASS', 'users/me', `role=${me.role} id=${me.id}`);

    const address = await ensureAddress(token);
    await addProductToCart(token);
    await estimateExpressDelivery(token, address);
    const orderId = await placeCodOrder(token, address);
    if (orderId) await fetchOrder(token, orderId);
  } catch (err) {
    log('FAIL', 'flow', err.message);
  }

  console.log('\n--- Summary ---');
  console.log(`PASS: ${pass}  FAIL: ${fail}  SKIP: ${skip}\n`);
  process.exit(fail > 0 ? 1 : 0);
}

main();
