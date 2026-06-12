// Production Environment Configuration
const config = {
  development: {
    port: 8080,
    database: {
      url: process.env.DATABASE_URL
    },
    redis: {
      url: process.env.REDIS_URL
    },
    cors: {
      origins: ['http://localhost:3000', 'http://127.0.0.1:3000']
    },
    jwt: {
      accessSecret: process.env.JWT_ACCESS_SECRET,
      refreshSecret: process.env.JWT_REFRESH_SECRET,
      accessExpiry: '15m',
      refreshExpiry: '30d'
    },
    otp: {
      ttl: 300,
      maxAttempts: 3,
      logToConsole: true
    },
    msg91: {
      authKey: process.env.MSG91_AUTH_KEY,
      templateId: process.env.MSG91_TEMPLATE_ID
    }
  },
  
  production: {
    port: process.env.PORT || 8080,
    database: {
      url: process.env.DATABASE_URL
    },
    redis: {
      url: process.env.REDIS_URL
    },
    cors: {
      origins: process.env.CORS_ORIGINS?.split(',') || []
    },
    jwt: {
      accessSecret: process.env.JWT_ACCESS_SECRET,
      refreshSecret: process.env.JWT_REFRESH_SECRET,
      accessExpiry: '15m',
      refreshExpiry: '30d'
    },
    otp: {
      ttl: parseInt(process.env.OTP_TTL_SECONDS) || 300,
      maxAttempts: parseInt(process.env.OTP_MAX_ATTEMPTS) || 3,
      logToConsole: false
    },
    msg91: {
      authKey: process.env.MSG91_AUTH_KEY,
      templateId: process.env.MSG91_TEMPLATE_ID
    }
  }
};

const env = process.env.NODE_ENV || 'development';
module.exports = config[env];
