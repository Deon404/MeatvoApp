const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const { logger } = require('./logger');

const MSG91_OTP_URL =
  process.env.MSG91_OTP_URL || 'https://control.msg91.com/api/v5/otp';
const MSG91_FLOW_URL =
  process.env.MSG91_FLOW_URL || 'https://control.msg91.com/api/v5/flow/';
const MSG91_OTP_VERIFY_URL =
  process.env.MSG91_OTP_VERIFY_URL || 'https://control.msg91.com/api/v5/otp/verify';
const MSG91_BALANCE_URL =
  process.env.MSG91_BALANCE_URL || 'https://control.msg91.com/api/balance.php';

const timeoutMs = Number(process.env.SMS_HTTP_TIMEOUT_MS || 10_000);
const balanceRouteType = Number(process.env.MSG91_BALANCE_ROUTE_TYPE || 4);

const client = axios.create({
  timeout: timeoutMs,
});

axiosRetry(client, {
  retries: Number(process.env.SMS_HTTP_RETRIES || 0),
  retryDelay: axiosRetry.exponentialDelay,
  retryCondition: (err) =>
    axiosRetry.isNetworkOrIdempotentRequestError(err) ||
    ['ECONNRESET', 'ETIMEDOUT', 'EAI_AGAIN', 'ENOTFOUND'].includes(err?.code),
});

let cachedBalance = { value: null, checkedAt: 0 };
const BALANCE_CACHE_MS = Number(process.env.MSG91_BALANCE_CACHE_MS || 60_000);

const formatPhoneForE164 = (phone) => {
  let cleaned = String(phone || '').replace(/[\s\-()]/g, '');
  if (!cleaned) return cleaned;
  if (cleaned.startsWith('00')) cleaned = `+${cleaned.slice(2)}`;
  if (cleaned.startsWith('+')) return cleaned;
  if (cleaned.startsWith('0')) cleaned = cleaned.slice(1);
  const cc = String(process.env.MSG91_COUNTRY_CODE || '91').replace(/\D/g, '') || '91';
  if (/^\d{10}$/.test(cleaned)) return `+${cc}${cleaned}`;
  if (cleaned.startsWith(cc)) return `+${cleaned}`;
  return `+${cc}${cleaned}`;
};

const formatPhoneForMSG91 = (phone) => {
  const e164 = formatPhoneForE164(phone);
  return e164.startsWith('+') ? e164.slice(1) : e164;
};

const getOtpTemplateVariables = () => {
  const raw = process.env.MSG91_OTP_VARIABLE;
  if (raw && raw.trim()) {
    return raw.split(',').map((s) => s.trim()).filter(Boolean);
  }
  return ['OTP'];
};

const getMsg91Config = () => {
  const authKey = process.env.MSG91_AUTH_KEY;
  const templateId = process.env.MSG91_OTP_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID;
  const senderId = process.env.MSG91_SENDER_ID;
  const flowId = process.env.MSG91_FLOW_ID || templateId;
  const dltTeId = process.env.MSG91_DLT_TE_ID || process.env.DLT_TE_ID;
  const otpVariables = getOtpTemplateVariables();

  if (!authKey || !templateId || !senderId) {
    throw new Error(
      'MSG91 env vars missing (MSG91_AUTH_KEY / MSG91_OTP_TEMPLATE_ID / MSG91_TEMPLATE_ID / MSG91_SENDER_ID)'
    );
  }

  return { authKey, templateId, senderId, flowId, dltTeId, otpVariables };
};

const isMsg91Success = (data) => {
  if (!data || typeof data !== 'object') return false;
  const type = String(data.type || data.status || '').toLowerCase();
  if (type === 'error' || type === 'failed' || type === 'failure') return false;
  return type === 'success';
};

const getMsg91Balance = async (authKey, routeType = balanceRouteType) => {
  const response = await client.get(MSG91_BALANCE_URL, {
    params: { authkey: authKey, type: routeType },
    timeout: Number(process.env.MSG91_BALANCE_TIMEOUT_MS || 4000),
  });
  const balance = Number(response.data);
  if (!Number.isFinite(balance)) {
    throw new Error('Unable to read MSG91 balance');
  }
  return balance;
};

const ensureMsg91Balance = async (authKey) => {
  if (String(process.env.MSG91_SKIP_BALANCE_CHECK || '').toLowerCase() === 'true') {
    return null;
  }

  const now = Date.now();
  if (cachedBalance.value !== null && now - cachedBalance.checkedAt < BALANCE_CACHE_MS) {
    if (cachedBalance.value <= 0) {
      throw new Error('MSG91 wallet balance is zero. Recharge MSG91 credits to deliver OTP SMS.');
    }
    return cachedBalance.value;
  }

  const balance = await getMsg91Balance(authKey);
  cachedBalance = { value: balance, checkedAt: now };
  logger.info('msg91_balance_checked', { balance, routeType: balanceRouteType });

  if (balance <= 0) {
    logger.warn('msg91_balance_api_zero', {
      routeType: balanceRouteType,
      hint:
        'MSG91 balance.php returned 0 but dashboard wallet may still have credits. Set MSG91_SKIP_BALANCE_CHECK=true or recharge.',
    });
    throw new Error('MSG91 wallet balance is zero. Recharge MSG91 credits to deliver OTP SMS.');
  }

  return balance;
};

/**
 * SendOTP v5 — minimal body only (extra keys cause MSG91 Error 400 / invalid template).
 * template_id must be from MSG91 → OTP → Templates (NOT OneAPI Flow ID unless using flow mode).
 */
const buildOtpPayload = ({ templateId, mobile, otp, senderId, dltTeId, otpVariables }) => {
  const payload = {
    template_id: String(templateId).trim(),
    mobile: String(mobile).trim(),
    otp: String(otp),
    otp_length: Number(process.env.MSG91_OTP_LENGTH || 4),
    otp_expiry: Number(process.env.MSG91_OTP_EXPIRY || 10),
    sender: String(senderId).trim(),
  };

  if (dltTeId) {
    payload.DLT_TE_ID = String(dltTeId).trim();
  }
  if (process.env.MSG91_ENTITY_ID) {
    payload.PE_ID = String(process.env.MSG91_ENTITY_ID).trim();
  }

  // DLT template "Your OTP for Meatvo is ##var##" — pass matching variable key(s) only
  for (const name of otpVariables || []) {
    if (name && name !== 'otp') {
      payload[name] = String(otp);
    }
  }

  return payload;
};

const throwIfMsg91ErrorBody = (response) => {
  const data = response?.data;
  if (!data || typeof data !== 'object') return;

  const code = data.code || data.error_code || data.errorCode;
  const message = data.message || data.msg || data.error;
  if (code === 400 || code === 211 || code === '400' || code === '211') {
    const err = new Error(message || 'MSG91 template/DLT configuration error');
    err.msg91 = data;
    err.httpStatus = response.status;
    throw err;
  }
  if (String(data.type || '').toLowerCase() === 'error') {
    const err = new Error(message || 'MSG91 OTP send rejected');
    err.msg91 = data;
    err.httpStatus = response.status;
    throw err;
  }
};

const sendViaOtpApi = async ({
  authKey,
  templateId,
  mobile,
  otp,
  senderId,
  dltTeId,
  otpVariables,
}) => {
  const response = await client.request({
    method: 'POST',
    url: MSG91_OTP_URL,
    headers: {
      authkey: authKey,
      'Content-Type': 'application/json',
    },
    data: buildOtpPayload({ templateId, mobile, otp, senderId, dltTeId, otpVariables }),
  });

  throwIfMsg91ErrorBody(response);
  const data = response.data;
  if (!isMsg91Success(data)) {
    const err = new Error(data?.message || 'MSG91 OTP send rejected');
    err.response = response;
    throw err;
  }
  return { channel: 'otp', data };
};

/**
 * SMS Templates (Send_otp with ##var##) — use template_id + recipients on /api/v5/flow/
 */
const sendViaTemplateFlowApi = async ({
  authKey,
  templateId,
  senderId,
  mobile,
  otp,
  otpVariables,
  dltTeId,
}) => {
  const recipient = { mobiles: mobile };
  for (const name of otpVariables || ['var']) {
    if (name) recipient[name] = String(otp);
  }

  const body = {
    template_id: String(templateId).trim(),
    sender: String(senderId).trim(),
    short_url: '0',
    recipients: [recipient],
  };
  if (dltTeId) body.DLT_TE_ID = String(dltTeId).trim();

  const response = await client.request({
    method: 'POST',
    url: MSG91_FLOW_URL,
    headers: {
      authkey: authKey,
      'Content-Type': 'application/json',
    },
    data: body,
  });

  throwIfMsg91ErrorBody(response);
  const data = response.data;
  if (!isMsg91Success(data)) {
    const err = new Error(data?.message || 'MSG91 template SMS rejected');
    err.response = response;
    throw err;
  }
  return { channel: 'template', data };
};

const sendViaFlowApi = async ({ authKey, flowId, senderId, mobile, otp, otpVariables, dltTeId }) => {
  const recipient = { mobiles: mobile };
  const otpVar = otpVariables[0] || 'OTP';
  recipient[otpVar] = String(otp);

  const body = {
    flow_id: String(flowId).trim(),
    sender: String(senderId).trim(),
    recipients: [recipient],
  };
  if (dltTeId) body.DLT_TE_ID = String(dltTeId).trim();

  const response = await client.request({
    method: 'POST',
    url: MSG91_FLOW_URL,
    headers: {
      authkey: authKey,
      'Content-Type': 'application/json',
    },
    data: body,
  });

  throwIfMsg91ErrorBody(response);
  const data = response.data;
  if (!isMsg91Success(data)) {
    const err = new Error(data?.message || 'MSG91 Flow send rejected');
    err.response = response;
    throw err;
  }
  return { channel: 'flow', data };
};

const sendSMS = async (phone, otp) => {
  const { authKey, templateId, senderId, flowId, dltTeId, otpVariables } = getMsg91Config();
  const mobile = formatPhoneForMSG91(phone);

  await ensureMsg91Balance(authKey);

  if (!dltTeId) {
    logger.warn('msg91_dlt_te_id_missing', {
      hint:
        'Set MSG91_DLT_TE_ID in .env (Jio DLT Content Template ID). Without it India SMS may fail with Error 400 in MSG91 logs.',
    });
  }

  logger.info('msg91_otp_request', {
    mobile: mobile.length > 6 ? `${mobile.slice(0, 4)}****${mobile.slice(-2)}` : '****',
    templateId,
    senderId,
    hasDltTeId: Boolean(dltTeId),
  });

  const deliveryMode = (process.env.MSG91_DELIVERY_MODE || 'template').toLowerCase();

  try {
    if (deliveryMode === 'template') {
      const result = await sendViaTemplateFlowApi({
        authKey,
        templateId,
        senderId,
        mobile,
        otp,
        otpVariables,
        dltTeId,
      });
      logger.info('msg91_send_success', {
        channel: result.channel,
        requestId: result.data?.message || result.data?.request_id,
      });
      return result.data;
    }

    if (deliveryMode === 'flow') {
      const result = await sendViaFlowApi({
        authKey,
        flowId,
        senderId,
        mobile,
        otp,
        otpVariables,
        dltTeId,
      });
      logger.info('msg91_send_success', { channel: result.channel, requestId: result.data?.message });
      return result.data;
    }

    const result = await sendViaOtpApi({
      authKey,
      templateId,
      mobile,
      otp,
      senderId,
      dltTeId,
      otpVariables,
    });
    logger.info('msg91_send_success', {
      channel: result.channel,
      requestId: result.data?.request_id,
    });
    return result.data;
  } catch (error) {
    const apiData = error.response?.data || error.msg91;
    const apiMessage = apiData?.message || apiData?.msg || error.message;
    logger.error('msg91_send_error', {
      httpStatus: error.response?.status || error.httpStatus,
      message: apiMessage,
      apiType: apiData?.type,
      code: apiData?.code,
    });

    const wrapped = new Error(
      /template|dlt|211|400/i.test(String(apiMessage))
        ? 'MSG91 template invalid. Use OTP Template ID from MSG91 → OTP section and set MSG91_DLT_TE_ID from Jio DLT.'
        : apiMessage || 'Failed to send SMS via MSG91'
    );
    wrapped.cause = error;
    wrapped.msg91 = apiData;
    wrapped.httpStatus = error.response?.status || error.httpStatus;
    throw wrapped;
  }
};

const verifySMS = async (phone, otp) => {
  const { authKey } = getMsg91Config();
  const mobile = formatPhoneForMSG91(phone);

  const response = await client.request({
    method: 'POST',
    url: MSG91_OTP_VERIFY_URL,
    headers: {
      authkey: authKey,
      'Content-Type': 'application/json',
    },
    data: { mobile, otp: String(otp) },
  });

  return response.data;
};

module.exports = {
  sendSMS,
  verifySMS,
  formatPhoneForE164,
  formatPhoneForMSG91,
  getMsg91Balance,
  ensureMsg91Balance,
  buildOtpPayload,
};
