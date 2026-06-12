const axios = require('axios');
const { sendSMS: sendMsg91Otp } = require('./msg91');
const { logger } = require('./logger');

const sendTwilioSms = async ({ to, body }) => {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM_NUMBER;
  if (!accountSid || !authToken || !from) {
    throw new Error('Twilio env vars missing (TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN/TWILIO_FROM_NUMBER)');
  }

  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const params = new URLSearchParams();
  params.set('To', to);
  params.set('From', from);
  params.set('Body', body);

  await axios.post(url, params, {
    auth: { username: accountSid, password: authToken },
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    timeout: Number(process.env.SMS_HTTP_TIMEOUT_MS || 10_000),
  });
};

/**
 * @returns {Promise<{ provider: string, response?: object }>}
 */
const sendOtpSms = async ({ phone, otp }) => {
  const provider = (process.env.SMS_PROVIDER || '').trim().toLowerCase();
  const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
  const allowFallbackToConsole =
    String(
      process.env.SMS_FALLBACK_TO_CONSOLE !== undefined
        ? process.env.SMS_FALLBACK_TO_CONSOLE
        : (!isProd).toString()
    ).toLowerCase() === 'true';
  const message = `Your Meatvo OTP is ${otp}. It expires in ${Math.round(
    Number(process.env.OTP_TTL_SECONDS || 300) / 60
  )} minutes.`;

  if (provider === 'console' || provider === 'log') {
    logger.info('otp_console_provider', { phone: phone.slice(0, 2) + '****' });
    return { provider: 'console' };
  }

  if (provider === 'twilio') {
    await sendTwilioSms({ to: phone, body: message });
    return { provider: 'twilio' };
  }

  if (provider === 'msg91' || provider === '') {
    // Avoid MSG91 Error 311 (duplicate request within 10 seconds)
    const maxAttempts = Number(process.env.SMS_MSG91_MAX_ATTEMPTS || 1);
    let lastError;

    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        const response = await sendMsg91Otp(phone, otp);
        return { provider: 'msg91', response };
      } catch (err) {
        lastError = err;
        if (attempt < maxAttempts) {
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
      }
    }

    const isBalanceError = /wallet balance|balance too low/i.test(lastError?.message || '');
    const devOtpMode =
      process.env.OTP_LOG_TO_CONSOLE === 'true' && process.env.NODE_ENV !== 'production';

    if (!allowFallbackToConsole && !(devOtpMode && isBalanceError)) {
      throw lastError;
    }

    logger.warn('sms_msg91_fallback_to_console', {
      phone: phone.slice(0, 4) + '****',
      attempts: maxAttempts,
      reason: lastError?.message,
    });
    return { provider: 'console', fallback: true, reason: lastError?.message };
  }

  throw new Error(`Unsupported SMS_PROVIDER: ${provider}`);
};

module.exports = { sendOtpSms };
