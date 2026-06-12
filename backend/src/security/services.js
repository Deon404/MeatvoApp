const { logger } = require('../utils/logger');

const csrfService = require('./csrf.service');
const cspService = require('./csp.service');
const deviceService = require('./device.service');
const sessionService = require('./session.service');
const paymentSecurity = require('./payment.security');
const fileSecurity = require('./file.security');
const redisSecurity = require('./redis.security');
const socketSecurity = require('./socket.security');
const jwtSecurity = require('./jwt.security');
const otpSecurity = require('./otp.security');
const accountLockoutService = require('./account-lockout.service');
const apiAbuseService = require('./api-abuse.service');
const mfaService = require('../modules/auth/mfa.service');

const getSecurityStats = () => {
  try {
    return {
      csrf: {
        activeTokens: csrfService.tokens.size,
      },
      csp: {
        activeNonces: cspService.nonces.size,
      },
      devices: {
        totalDevices: deviceService.devices.size,
      },
      sessions: {
        ...sessionService.getSessionStats(),
      },
      payments: {
        ...paymentSecurity.getPaymentSecurityStats(),
      },
      files: {
        ...fileSecurity.getFileSecurityStats(),
      },
      redis: {
        ...redisSecurity.getSecurityStats(),
      },
      sockets: {
        ...socketSecurity.getSecurityStats(),
      },
      jwt: {
        ...jwtSecurity.getSecurityStats(),
      },
      otp: {
        ...otpSecurity.getSecurityStats(),
      },
    };
  } catch (error) {
    logger.error('security_stats_error', { error: error.message });
    return {};
  }
};

module.exports = {
  csrfService,
  cspService,
  deviceService,
  sessionService,
  paymentSecurity,
  fileSecurity,
  redisSecurity,
  socketSecurity,
  jwtSecurity,
  otpSecurity,
  accountLockoutService,
  apiAbuseService,
  mfaService,
  getSecurityStats,
};
