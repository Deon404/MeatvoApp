require('dotenv').config();

const BASE_URL = process.env.OTP_TEST_BASE_URL || 'http://localhost:8080';
const TEST_PHONE = process.env.OTP_TEST_PHONE || '+917061036957';

const maskPhone = (phone) => {
  if (!phone || phone.length < 6) return '****';
  return `${phone.slice(0, 3)}******${phone.slice(-2)}`;
};

async function postJson(path, body, headers = {}) {
  const response = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });

  const json = await response.json().catch(() => ({}));
  return { response, json };
}

async function getJson(path, headers = {}) {
  const response = await fetch(`${BASE_URL}${path}`, {
    method: 'GET',
    headers,
  });
  const json = await response.json().catch(() => ({}));
  return { response, json };
}

async function run() {
  console.log(`OTP E2E started for ${maskPhone(TEST_PHONE)} on ${BASE_URL}`);

  const health = await getJson('/health');
  if (!health.response.ok) {
    throw new Error(`Health check failed (${health.response.status})`);
  }
  console.log('Health check passed.');

  const send = await postJson('/api/auth/send-otp', { phone: TEST_PHONE });
  if (!send.response.ok || !send.json?.success) {
    throw new Error(
      `send-otp failed (${send.response.status}): ${send.json?.message || 'Unknown error'}`
    );
  }

  const otp = send.json?.data?.devOTP;
  if (!otp) {
    throw new Error(
      'devOTP missing in response. Enable development mode and OTP_LOG_TO_CONSOLE for automated check.'
    );
  }
  console.log('OTP send passed.');

  const verify = await postJson('/api/auth/verify-otp', {
    phone: TEST_PHONE,
    otp,
  });
  if (!verify.response.ok || !verify.json?.success) {
    throw new Error(
      `verify-otp failed (${verify.response.status}): ${verify.json?.message || 'Unknown error'}`
    );
  }

  const accessToken = verify.json?.data?.accessToken;
  if (!accessToken) {
    throw new Error('verify-otp succeeded but accessToken missing.');
  }
  console.log('OTP verify passed, token issued.');

  const me = await getJson('/api/auth/me', {
    Authorization: `Bearer ${accessToken}`,
  });
  if (!me.response.ok || !me.json?.success || !me.json?.data?.user?.id) {
    throw new Error(`me endpoint failed (${me.response.status}).`);
  }

  const role = me.json?.data?.user?.role || 'unknown';
  console.log(`Auth me passed. User role: ${role}`);
  console.log('OTP E2E completed successfully.');
}

run().catch((error) => {
  console.error(`OTP E2E failed: ${error.message}`);
  process.exit(1);
});
