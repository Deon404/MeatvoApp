const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const https = require('https');

const timeoutMs = Number(process.env.SMS_HTTP_TIMEOUT_MS || 10_000);

const client = axios.create({
    timeout: timeoutMs,
});

axiosRetry(client, {
    retries: Number(process.env.SMS_HTTP_RETRIES || 2),
    retryDelay: axiosRetry.exponentialDelay,
    retryCondition: (err) =>
        axiosRetry.isNetworkOrIdempotentRequestError(err) ||
        ['ECONNRESET', 'ETIMEDOUT', 'EAI_AGAIN', 'ENOTFOUND'].includes(err?.code),
});

/**
 * Send OTP via MSG91 API
 * @param {string} phone - Phone number with country code (e.g., 91XXXXXXXXXX)
 * @param {string} otp - 6 digit OTP
 */
const sendSMS = async (phone, otp) => {
    try {
        const authKey = process.env.MSG91_AUTH_KEY;
        const templateId = process.env.MSG91_OTP_TEMPLATE_ID;
        if (!authKey || !templateId) {
            throw new Error('MSG91 env vars missing (MSG91_AUTH_KEY / MSG91_OTP_TEMPLATE_ID)');
        }

        const options = {
            method: 'GET',
            url: 'https://api.msg91.com/api/v5/otp',
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'application/json',
                'Connection': 'keep-alive',
                'Host': 'api.msg91.com'
            },
            params: {
                authkey: authKey,
                template_id: templateId,
                mobile: phone,
                otp: otp,
                userip: '127.0.0.1'
            },
            httpsAgent: new https.Agent({
                rejectUnauthorized: false,
                secureProtocol: 'TLSv1_2_method'
            })
        };

        const response = await client.request(options);
        return response.data;
    } catch (error) {
        console.error('MSG91 Error:', error.response?.data || error.message);
        throw new Error('Failed to send SMS', { cause: error });
    }
};

module.exports = { sendSMS };
