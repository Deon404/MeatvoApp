const axios = require('axios');
const { logger } = require('../../utils/logger');

const API_VERSION = '2023-08-01';
const SANDBOX_BASE_URL = 'https://sandbox.cashfree.com/pg';
const PRODUCTION_BASE_URL = 'https://api.cashfree.com/pg';

function getCashfreeEnv() {
  const env = String(process.env.CASHFREE_ENV || '').toLowerCase();
  if (env !== 'sandbox' && env !== 'production') {
    throw new Error('CASHFREE_ENV must be explicitly set to "sandbox" or "production"');
  }
  return env;
}

function getBaseUrl() {
  return getCashfreeEnv() === 'production' ? PRODUCTION_BASE_URL : SANDBOX_BASE_URL;
}

function getCredentials() {
  const appId = process.env.CASHFREE_APP_ID;
  const secretKey = process.env.CASHFREE_SECRET_KEY;

  if (!appId || !secretKey) {
    throw new Error(
      'Cashfree configuration missing. Set CASHFREE_APP_ID and CASHFREE_SECRET_KEY.',
    );
  }

  return { appId, secretKey };
}

function buildHeaders() {
  const { appId, secretKey } = getCredentials();

  return {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    'x-api-version': API_VERSION,
    'x-client-id': appId,
    'x-client-secret': secretKey,
  };
}

/** Cashfree customer_id: alphanumeric, underscore, hyphen only. */
function sanitizeCustomerId(value) {
  const sanitized = String(value).replace(/[^a-zA-Z0-9_-]/g, '');
  if (!sanitized) {
    throw new Error('Cashfree createOrder failed: customer_id is required');
  }
  return sanitized;
}

/** Cashfree customer_phone: digits only (E.164 without +). */
function normalizeCustomerPhone(phone) {
  const digits = String(phone).replace(/\D/g, '');
  if (!digits) {
    throw new Error('Cashfree createOrder failed: customerPhone is required');
  }
  return digits;
}

function formatAxiosError(error, context) {
  const status = error.response?.status;
  const data = error.response?.data;
  const message =
    data?.message ||
    data?.error?.message ||
    error.message ||
    'Unknown Cashfree API error';

  const detail = status ? `HTTP ${status}: ${message}` : message;
  return new Error(`Cashfree ${context} failed: ${detail}`);
}

/**
 * Create a Cashfree payment order.
 * @param {Object} params
 * @param {string} params.orderId - Merchant order ID
 * @param {number} params.amount - Order amount in major currency units (e.g. INR rupees)
 * @param {string} params.currency - ISO currency code (e.g. INR)
 * @param {string} params.customerPhone - Customer phone number
 * @param {string} [params.customerEmail] - Customer email
 * @param {string} [params.customerName] - Customer name
 * @param {string} params.returnUrl - Redirect URL after payment
 * @returns {Promise<{ payment_session_id: string, cf_order_id: string }>}
 */
async function createOrder({
  orderId,
  amount,
  currency,
  customerPhone,
  customerEmail,
  customerName,
  returnUrl,
}) {
  if (!orderId) throw new Error('Cashfree createOrder failed: orderId is required');
  if (amount == null || Number(amount) <= 0) {
    throw new Error('Cashfree createOrder failed: amount must be a positive number');
  }
  if (!currency) throw new Error('Cashfree createOrder failed: currency is required');
  if (!customerPhone) throw new Error('Cashfree createOrder failed: customerPhone is required');
  if (!returnUrl) throw new Error('Cashfree createOrder failed: returnUrl is required');

  const payload = {
    order_id: String(orderId),
    order_amount: Number(amount),
    order_currency: String(currency).toUpperCase(),
    customer_details: {
      customer_id: sanitizeCustomerId(customerPhone),
      customer_phone: normalizeCustomerPhone(customerPhone),
      ...(customerEmail ? { customer_email: customerEmail } : {}),
      ...(customerName ? { customer_name: customerName } : {}),
    },
    order_meta: {
      return_url: returnUrl,
    },
  };

  const cashfreeEnv = getCashfreeEnv();

  try {
    logger.info('cashfree_create_order_start', {
      orderId: String(orderId),
      amount: Number(amount),
      currency: String(currency).toUpperCase(),
      cashfreeEnv,
      baseUrl: getBaseUrl(),
    });

    const response = await axios.post(`${getBaseUrl()}/orders`, payload, {
      headers: buildHeaders(),
      timeout: 30000,
    });

    const { payment_session_id, cf_order_id } = response.data || {};

    if (!payment_session_id) {
      logger.error('cashfree_create_order_missing_session', {
        orderId: String(orderId),
        cashfreeEnv,
        responseData: response.data,
      });
      throw new Error('Cashfree createOrder failed: payment_session_id missing in response');
    }

    logger.info('cashfree_create_order_success', {
      orderId: String(orderId),
      cf_order_id: cf_order_id != null ? String(cf_order_id) : String(orderId),
      cashfreeEnv,
    });

    return {
      payment_session_id,
      cf_order_id: cf_order_id != null ? String(cf_order_id) : String(orderId),
    };
  } catch (error) {
    if (error.message.startsWith('Cashfree createOrder failed:')) throw error;
    const formatted = formatAxiosError(error, 'createOrder');
    logger.error('cashfree_create_order_failed', {
      orderId: String(orderId),
      cashfreeEnv,
      status: error.response?.status,
      responseData: error.response?.data,
      message: formatted.message,
    });
    throw formatted;
  }
}

/**
 * Fetch Cashfree order status.
 * @param {string} orderId - Merchant order ID
 * @returns {Promise<{ order_status: string, payment_session_id: string|null }>}
 */
async function getOrderStatus(orderId) {
  if (!orderId) throw new Error('Cashfree getOrderStatus failed: orderId is required');

  try {
    const response = await axios.get(
      `${getBaseUrl()}/orders/${encodeURIComponent(String(orderId))}`,
      {
        headers: buildHeaders(),
        timeout: 30000,
      },
    );

    const { order_status, payment_session_id } = response.data || {};

    if (!order_status) {
      throw new Error('Cashfree getOrderStatus failed: order_status missing in response');
    }

    return {
      order_status,
      payment_session_id: payment_session_id || null,
    };
  } catch (error) {
    if (error.message.startsWith('Cashfree getOrderStatus failed:')) throw error;
    throw formatAxiosError(error, 'getOrderStatus');
  }
}

/**
 * Fetch payments for a Cashfree order.
 * @param {string} orderId - Merchant order ID
 * @returns {Promise<Array<Object>>}
 */
async function getPayments(orderId) {
  if (!orderId) throw new Error('Cashfree getPayments failed: orderId is required');

  try {
    const response = await axios.get(
      `${getBaseUrl()}/orders/${encodeURIComponent(String(orderId))}/payments`,
      {
        headers: buildHeaders(),
        timeout: 30000,
      },
    );

    const payments = response.data;

    if (!Array.isArray(payments)) {
      throw new Error('Cashfree getPayments failed: expected an array of payment objects');
    }

    return payments;
  } catch (error) {
    if (error.message.startsWith('Cashfree getPayments failed:')) throw error;
    throw formatAxiosError(error, 'getPayments');
  }
}

module.exports = {
  createOrder,
  getOrderStatus,
  getPayments,
  getCashfreeEnv,
  getBaseUrl,
};
