const axios = require('axios');
const { sendSMS: sendMsg91Otp } = require('./msg91');

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

const sendOtpSms = async ({ phone, otp }) => {
  const provider = (process.env.SMS_PROVIDER || '').trim().toLowerCase();
  const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
  const allowFallbackToConsole =
    String(process.env.SMS_FALLBACK_TO_CONSOLE !== undefined ? process.env.SMS_FALLBACK_TO_CONSOLE : (!isProd).toString()).toLowerCase() === 'true';
  const message = `Your Meatvo OTP is ${otp}. It expires in ${Math.round(
    Number(process.env.OTP_TTL_SECONDS || 300) / 60
  )} minutes.`;

  if (provider === 'console' || provider === 'log') {
    console.log(`[OTP][${phone}] ${otp}`);
    return;
  }

  if (provider === 'twilio') {
    await sendTwilioSms({ to: phone, body: message });
    return;
  }

  if (provider === 'msg91' || provider === '') {
    // MSG91 OTP API expects mobile without the leading "+"
    const msg91Phone = phone.startsWith('+') ? phone.slice(1) : phone;
    
    // MSG91 RETRY LOGIC (Critical) - Retry mechanism with max 3 attempts
    let retries = 3;
    let lastError;
    
    while (retries > 0) {
      try {
        await sendMsg91Otp(msg91Phone, otp);
        return; // Success - exit function
      } catch (err) {
        lastError = err;
        retries--;
        
        if (retries > 0) {
          // Wait 1 second before retry
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
      }
    }
    
    // All retries failed
    if (!allowFallbackToConsole) throw lastError;
    console.warn('MSG91 unavailable after 3 retries; falling back to console OTP for dev.');
    console.log(`[OTP][${phone}] ${otp}`);
    return;
  }

  throw new Error(`Unsupported SMS_PROVIDER: ${provider}`);
};

module.exports = { sendOtpSms };
