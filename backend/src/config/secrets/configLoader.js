const { logger } = require('../../utils/logger');
const secretManager = require('./secretManager');
const {
  DEFAULTS,
  SECRET_MAP,
  REQUIRED_ALWAYS,
  NUMERIC_BOUNDS,
} = require('../env.constants');

const SECRET_NAMES = Object.freeze(
  Object.fromEntries(Object.keys(SECRET_MAP).map((name) => [name, name]))
);

const CONFIG_REQUIRED = REQUIRED_ALWAYS.filter((key) =>
  Object.values(SECRET_MAP).includes(key)
);

const PROD_REQUIRED = [
  SECRET_MAP.sentry_dsn,
  SECRET_MAP.firebase_api_key,
  SECRET_MAP.google_maps_api_key,
];

class ConfigLoader {
  constructor() {
    this.config = {};
    this.isLoaded = false;
  }

  async load() {
    if (this.isLoaded) {
      return this.config;
    }

    try {
      logger.info('config_loading_started');

      // Initialize secret manager
      secretManager.initialize();

      // Load base configuration
      this.config = {
        // Server Configuration
        PORT: parseInt(process.env.PORT) || DEFAULTS.PORT,
        NODE_ENV: process.env.NODE_ENV || DEFAULTS.NODE_ENV,
        LOG_LEVEL: process.env.LOG_LEVEL || DEFAULTS.LOG_LEVEL,
        TRUST_PROXY: process.env.TRUST_PROXY === 'true',

        // Database Configuration
        DATABASE_URL: await secretManager.getSecret(SECRET_NAMES.database_url),
        REDIS_URL: await secretManager.getSecret(SECRET_NAMES.redis_url),

        // Authentication Configuration
        JWT_ACCESS_SECRET: await secretManager.getSecret(SECRET_NAMES.jwt_access_secret),
        JWT_REFRESH_SECRET: await secretManager.getSecret(SECRET_NAMES.jwt_refresh_secret),
        OTP_HASH_SECRET: await secretManager.getSecret(SECRET_NAMES.otp_hash_secret),
        JWT_ACCESS_EXPIRY: process.env.JWT_ACCESS_EXPIRY || DEFAULTS.JWT_ACCESS_EXPIRY,
        JWT_REFRESH_EXPIRY: process.env.JWT_REFRESH_EXPIRY || DEFAULTS.JWT_REFRESH_EXPIRY,

        // External Services Configuration
        MSG91_AUTH_KEY: await secretManager.getSecret(SECRET_NAMES.msg91_api_key),
        MSG91_API_KEY: await secretManager.getSecret(SECRET_NAMES.msg91_api_key),
        MSG91_OTP_TEMPLATE_ID: process.env.MSG91_OTP_TEMPLATE_ID || DEFAULTS.MSG91_OTP_TEMPLATE_ID,
        MSG91_SENDER_ID: process.env.MSG91_SENDER_ID || DEFAULTS.MSG91_SENDER_ID,
        SMS_PROVIDER: process.env.SMS_PROVIDER || DEFAULTS.SMS_PROVIDER,

        // Payment Configuration
        PHONEPE_MERCHANT_ID: await secretManager.getSecret(SECRET_NAMES.phonepe_merchant_id),
        PHONEPE_SALT_KEY: await secretManager.getSecret(SECRET_NAMES.phonepe_salt_key),
        PHONEPE_ENVIRONMENT: process.env.PHONEPE_ENVIRONMENT || DEFAULTS.PHONEPE_ENVIRONMENT,

        // Maps Configuration
        GOOGLE_MAPS_API_KEY: await secretManager.getSecret(SECRET_NAMES.google_maps_api_key),

        // Firebase Configuration
        FIREBASE_API_KEY: await secretManager.getSecret(SECRET_NAMES.firebase_api_key),
        FIREBASE_AUTH_DOMAIN: process.env.FIREBASE_AUTH_DOMAIN,
        FIREBASE_PROJECT_ID: await secretManager.getSecret(SECRET_NAMES.firebase_project_id),
        FIREBASE_MESSAGING_SENDER_ID: await secretManager.getSecret(SECRET_NAMES.firebase_messaging_sender_id),
        FIREBASE_APP_ID: await secretManager.getSecret(SECRET_NAMES.firebase_app_id),

        // AWS Configuration (for production)
        AWS_REGION: process.env.AWS_REGION || DEFAULTS.AWS_REGION,
        AWS_S3_BUCKET: process.env.AWS_S3_BUCKET,

        // Monitoring Configuration
        SENTRY_DSN: await secretManager.getSecret(SECRET_NAMES.sentry_dsn),
        ELASTICSEARCH_URL: process.env.ELASTICSEARCH_URL || DEFAULTS.ELASTICSEARCH_URL,

        // CORS Configuration
        CORS_ORIGINS: process.env.CORS_ORIGINS?.split(',').map(s => s.trim()) || DEFAULTS.CORS_ORIGINS,
        CORS_ALLOW_NULL_ORIGIN: process.env.CORS_ALLOW_NULL_ORIGIN === 'true',

        // Development Configuration
        DEV_AUTH_BYPASS_ENABLED:
          process.env.NODE_ENV !== 'production' && process.env.DEV_AUTH_BYPASS_ENABLED === 'true',
        DEV_AUTH_BYPASS_SECRET: process.env.DEV_AUTH_BYPASS_SECRET,

        // Application Configuration
        DEFAULT_COUNTRY_CODE: process.env.DEFAULT_COUNTRY_CODE || DEFAULTS.DEFAULT_COUNTRY_CODE,
        MAX_LOGIN_ATTEMPTS: parseInt(process.env.MAX_LOGIN_ATTEMPTS) || DEFAULTS.MAX_LOGIN_ATTEMPTS,
        LOCKOUT_DURATION: parseInt(process.env.LOCKOUT_DURATION) || DEFAULTS.LOCKOUT_DURATION,

        // Rate Limiting Configuration
        RATE_LIMIT_WINDOW_MS: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || DEFAULTS.RATE_LIMIT_WINDOW_MS,
        RATE_LIMIT_MAX_REQUESTS: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || DEFAULTS.RATE_LIMIT_MAX_REQUESTS,
        AUTH_RATE_LIMIT_MAX_REQUESTS: parseInt(process.env.AUTH_RATE_LIMIT_MAX_REQUESTS) || DEFAULTS.AUTH_RATE_LIMIT_MAX_REQUESTS,

        // File Upload Configuration
        MAX_FILE_SIZE: parseInt(process.env.MAX_FILE_SIZE) || DEFAULTS.MAX_FILE_SIZE,
        ALLOWED_FILE_TYPES: process.env.ALLOWED_FILE_TYPES?.split(',') || DEFAULTS.ALLOWED_FILE_TYPES,

        // Backup Configuration
        BACKUP_SCHEDULE: process.env.BACKUP_SCHEDULE || DEFAULTS.BACKUP_SCHEDULE,
        BACKUP_RETENTION_DAYS: parseInt(process.env.BACKUP_RETENTION_DAYS) || DEFAULTS.BACKUP_RETENTION_DAYS,
        AWS_BACKUP_BUCKET: process.env.AWS_BACKUP_BUCKET,

        // Notification Configuration
        FCM_SERVER_KEY: await secretManager.getSecret(SECRET_NAMES.fcm_server_key),
        NOTIFICATION_COOLDOWN_MS: parseInt(process.env.NOTIFICATION_COOLDOWN_MS) || DEFAULTS.NOTIFICATION_COOLDOWN_MS,
        MAX_NOTIFICATIONS_PER_MINUTE: parseInt(process.env.MAX_NOTIFICATIONS_PER_MINUTE) || DEFAULTS.MAX_NOTIFICATIONS_PER_MINUTE,
      };

      // Validate required configuration
      this.validateConfig();

      this.isLoaded = true;
      logger.info('config_loaded_successfully', {
        environment: this.config.NODE_ENV,
        port: this.config.PORT,
      });

      return this.config;
    } catch (error) {
      logger.error('config_loading_failed', { error: error.message });
      throw new Error(`Failed to load configuration: ${error.message}`);
    }
  }

  validateConfig() {
    const missing = CONFIG_REQUIRED.filter((key) => !this.config[key]);

    if (missing.length > 0) {
      throw new Error(`Missing required configuration: ${missing.join(', ')}`);
    }

    // Validate environment-specific requirements
    if (this.config.NODE_ENV === 'production') {
      const prodMissing = PROD_REQUIRED.filter((key) => !this.config[key]);
      if (prodMissing.length > 0) {
        logger.warn('production_config_missing', { missing: prodMissing });
      }
    }

    // Validate numeric values
    for (const [key, validation] of Object.entries(NUMERIC_BOUNDS)) {
      const value = this.config[key];
      if (value < validation.min || value > validation.max) {
        throw new Error(`${key} must be between ${validation.min} and ${validation.max}`);
      }
    }
  }

  get(key) {
    if (!this.isLoaded) {
      throw new Error('Configuration not loaded. Call load() first.');
    }
    return this.config[key];
  }

  getAll() {
    if (!this.isLoaded) {
      throw new Error('Configuration not loaded. Call load() first.');
    }
    return { ...this.config };
  }

  // Reload configuration (useful for secret rotation)
  async reload() {
    secretManager.clearCache();
    this.isLoaded = false;
    return await this.load();
  }
}

module.exports = new ConfigLoader();
