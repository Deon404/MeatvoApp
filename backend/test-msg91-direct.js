const fs = require('fs');
const path = require('path');
const util = require('util');
const axios = require('axios');
const dotenv = require('dotenv');

const ENV_PATH = path.resolve(__dirname, '.env');
const OUTPUT_PATH = path.resolve(__dirname, 'test-msg91-direct-output.log');
const MSG91_URL = 'https://api.msg91.com/api/v5/otp';
dotenv.config({ path: ENV_PATH });
const TEST_MOBILE = process.env.OTP_TEST_MOBILE;
const TEST_OTP = process.env.OTP_TEST_OTP;
const MSG91_SOURCE_PATH = path.resolve(__dirname, 'src', 'utils', 'msg91.js');
const SMS_SOURCE_PATH = path.resolve(__dirname, 'src', 'utils', 'sms.js');
const AUTH_CONTROLLER_PATH = path.resolve(__dirname, 'src', 'modules', 'auth', 'auth.controller.js');

const inspect = (value) =>
  util.inspect(value, {
    depth: null,
    colors: true,
    compact: false,
    breakLength: 120,
  });

const inspectPlain = (value) =>
  util.inspect(value, {
    depth: null,
    colors: false,
    compact: false,
    breakLength: 120,
  });

const logLines = [];

const appendLogLine = (line = '') => {
  logLines.push(String(line));
};

const maskMiddle = (value) => {
  const str = String(value || '');
  if (!str) return '(missing)';
  if (str.length <= 8) return `${str.slice(0, 2)}****${str.slice(-2)}`;
  return `${str.slice(0, 4)}${'*'.repeat(Math.max(4, str.length - 8))}${str.slice(-4)}`;
};

const redactHeaders = (headers) => {
  const clone = { ...(headers || {}) };
  if (clone.authkey) {
    clone.authkey = maskMiddle(clone.authkey);
  }
  if (clone.Authkey) {
    clone.Authkey = maskMiddle(clone.Authkey);
  }
  if (clone.Authorization) {
    clone.Authorization = '[redacted]';
  }
  return clone;
};

const printSection = (title, value) => {
  appendLogLine('');
  appendLogLine(`=== ${title} ===`);
  console.log(`\n=== ${title} ===`);
  if (typeof value === 'string') {
    appendLogLine(value);
    console.log(value);
    return;
  }
  appendLogLine(inspectPlain(value));
  console.log(inspect(value));
};

const extractSourceValue = (source, regex) => {
  const match = source.match(regex);
  return match ? match[1] : null;
};

const loadEnv = () => {
  appendLogLine(`Loading env from: ${ENV_PATH}`);
  console.log(`Loading env from: ${ENV_PATH}`);
  const result = dotenv.config({ path: ENV_PATH });
  if (result.error) {
    throw result.error;
  }
  printSection('dotenv result', {
    parsedKeys: Object.keys(result.parsed || {}).sort(),
  });
};

const printMsg91EnvVars = () => {
  const msg91Keys = Object.keys(process.env)
    .filter((key) => key.startsWith('MSG91_'))
    .sort();

  const entries = msg91Keys.map((key) => [
    key,
    key === 'MSG91_AUTH_KEY' ? maskMiddle(process.env[key]) : process.env[key],
  ]);

  printSection('MSG91 env vars', Object.fromEntries(entries));
  printSection('Relevant SMS env vars', {
    SMS_PROVIDER: process.env.SMS_PROVIDER,
    SMS_HTTP_TIMEOUT_MS: process.env.SMS_HTTP_TIMEOUT_MS,
    SMS_HTTP_RETRIES: process.env.SMS_HTTP_RETRIES,
    SMS_FALLBACK_TO_CONSOLE: process.env.SMS_FALLBACK_TO_CONSOLE,
  });
};

const printCurrentMsg91Code = () => {
  const msg91Source = fs.readFileSync(MSG91_SOURCE_PATH, 'utf8');
  const smsSource = fs.readFileSync(SMS_SOURCE_PATH, 'utf8');
  const authControllerSource = fs.readFileSync(AUTH_CONTROLLER_PATH, 'utf8');

  const method = extractSourceValue(msg91Source, /method:\s*['"`]([^'"`]+)['"`]/);
  const url = extractSourceValue(msg91Source, /url:\s*['"`]([^'"`]+)['"`]/);
  const retriesBlockPresent = /axiosRetry\s*\(\s*client\s*,\s*\{/.test(msg91Source);
  const msg91PhoneNormalization =
    extractSourceValue(smsSource, /const msg91Phone = phone\.startsWith\('\+'\) \? phone\.slice\(1\) : phone;/) ||
    "phone.startsWith('+') ? phone.slice(1) : phone";
  const smsRetryLoopPresent = /while\s*\(\s*retries\s*>\s*0\s*\)/.test(smsSource);
  const authUsesSendOtpSms = /await sendOtpSms\(\{ phone, otp \}\);/.test(authControllerSource);

  const currentRequest = {
    sourceFile: MSG91_SOURCE_PATH,
    method: method || '(not found)',
    url: url || '(not found)',
    headers: redactHeaders({
      authkey: process.env.MSG91_AUTH_KEY,
      'Content-Type': 'application/json',
    }),
    body: {
      template_id: process.env.MSG91_OTP_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID,
      mobile: TEST_MOBILE,
      otp: TEST_OTP,
    },
    params: null,
    notes: [
      'msg91.js uses axios client.request(options) with JSON body in `data`, not query params.',
      'sms.js removes a leading `+` before passing phone to msg91.js.',
      'auth.controller.js calls sendOtpSms({ phone, otp }) after generating/storing OTP.',
    ],
  };

  const axiosRetryConfig = retriesBlockPresent
    ? {
        presentInMsg91: true,
        timeoutMs: Number(process.env.SMS_HTTP_TIMEOUT_MS || 10000),
        retries: Number(process.env.SMS_HTTP_RETRIES || 2),
        retryDelay: 'axiosRetry.exponentialDelay',
        retryCondition:
          "axiosRetry.isNetworkOrIdempotentRequestError(err) || ['ECONNRESET', 'ETIMEDOUT', 'EAI_AGAIN', 'ENOTFOUND'].includes(err?.code)",
        changesRequestPayload: false,
        note: 'axios-retry request body/headers/url ko rewrite nahi karta; matching failures par same request ko dubara bhej sakta hai.',
      }
    : {
        presentInMsg91: false,
      };

  printSection('Current msg91.js request shape', currentRequest);
  printSection('Current sms.js behavior', {
    sourceFile: SMS_SOURCE_PATH,
    provider: process.env.SMS_PROVIDER,
    phoneNormalization: msg91PhoneNormalization,
    smsRetryLoopPresent,
    retryAttemptsInSmsJs: 3,
  });
  printSection('Current auth.controller.js behavior', {
    sourceFile: AUTH_CONTROLLER_PATH,
    authUsesSendOtpSms,
  });
  printSection('axios-retry config in msg91.js', axiosRetryConfig);
};

const makeDirectMsg91Call = async () => {
  const requestConfig = {
    method: 'POST',
    url: MSG91_URL,
    headers: {
      authkey: process.env.MSG91_AUTH_KEY,
      'Content-Type': 'application/json',
    },
    data: {
      template_id: process.env.MSG91_OTP_TEMPLATE_ID,
      mobile: TEST_MOBILE,
      otp: TEST_OTP,
    },
    timeout: Number(process.env.SMS_HTTP_TIMEOUT_MS || 10000),
    validateStatus: () => true,
  };

  printSection('Direct MSG91 request config (redacted for console)', {
    ...requestConfig,
    headers: redactHeaders(requestConfig.headers),
  });

  const response = await axios(requestConfig);

  printSection('MSG91 raw response status', response.status);
  printSection('MSG91 raw response headers', response.headers);
  printSection('MSG91 raw response body', response.data);
};

const printError = (error) => {
  printSection('Direct MSG91 error summary', {
    name: error.name,
    message: error.message,
    code: error.code,
    errno: error.errno,
    syscall: error.syscall,
    address: error.address,
    port: error.port,
  });

  if (error.config) {
    printSection('Axios error config', {
      method: error.config.method,
      url: error.config.url,
      timeout: error.config.timeout,
      headers: redactHeaders(error.config.headers),
      data: error.config.data,
    });
  }

  if (error.response) {
    printSection('Axios error response status', error.response.status);
    printSection('Axios error response headers', error.response.headers);
    printSection('Axios error response body', error.response.data);
  }

  if (error.request) {
    printSection('Axios error request details', {
      finished: error.request.finished,
      destroyed: error.request.destroyed,
      path: error.request.path,
      method: error.request.method,
      host: error.request.host,
      protocol: error.request.protocol,
    });
  }

  printSection('Error stack', error.stack || '(no stack)');
};

const flushLogFile = () => {
  fs.writeFileSync(OUTPUT_PATH, `${logLines.join('\n')}\n`, 'utf8');
  console.log(`\nSaved debug output to: ${OUTPUT_PATH}`);
};

const main = async () => {
  loadEnv();
  printMsg91EnvVars();
  printCurrentMsg91Code();
  await makeDirectMsg91Call();
  flushLogFile();
};

main().catch((error) => {
  printError(error);
  flushLogFile();
  process.exitCode = 1;
});
