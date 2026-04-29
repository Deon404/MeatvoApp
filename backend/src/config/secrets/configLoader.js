const { logger } = require('../../utils/logger');
const secretManager = require('./secretManager');

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
        PORT: parseInt(process.env.PORT) || 5000,
        NODE_ENV: process.env.NODE_ENV || 'development',
        LOG_LEVEL: process.env.LOG_LEVEL || 'info',
        TRUST_PROXY: process.env.TRUST_PROXY === 'true',

        // Database Configuration
        DATABASE_URL: await secretManager.getSecret('database_url'),
        REDIS_URL: await secretManager.getSecret('redis_url'),

        // Authentication Configuration
        JWT_ACCESS_SECRET: await secretManager.getSecret('jwt_access_secret'),
        JWT_REFRESH_SECRET: await secretManager.getSecret('jwt_refresh_secret'),
        OTP_HASH_SECRET: await secretManager.getSecret('otp_hash_secret'),
        JWT_ACCESS_EXPIRY: process.env.JWT_ACCESS_EXPIRY || '15m',
        JWT_REFRESH_EXPIRY: process.env.JWT_REFRESH_EXPIRY || '7d',

        // External Services Configuration
        MSG91_API_KEY: await secretManager.getSecret('msg91_api_key'),
        MSG91_OTP_TEMPLATE_ID: process.env.MSG91_OTP_TEMPLATE_ID || 'meatvo_otp',
        MSG91_SENDER_ID: process.env.MSG91_SENDER_ID || 'MEATVO',
        SMS_PROVIDER: process.env.SMS_PROVIDER || 'msg91',

        // Payment Configuration
        PHONEPE_MERCHANT_ID: await secretManager.getSecret('phonepe_merchant_id'),
        PHONEPE_SALT_KEY: await secretManager.getSecret('phonepe_salt_key'),
        PHONEPE_ENVIRONMENT: process.env.PHONEPE_ENVIRONMENT || 'UAT',

        // Maps Configuration
        GOOGLE_MAPS_API_KEY: await secretManager.getSecret('google_maps_api_key'),

        // Firebase Configuration
        FIREBASE_API_KEY: await secretManager.getSecret('firebase_api_key'),
        FIREBASE_AUTH_DOMAIN: process.env.FIREBASE_AUTH_DOMAIN,
        FIREBASE_PROJECT_ID: await secretManager.getSecret('firebase_project_id'),
        FIREBASE_MESSAGING_SENDER_ID: await secretManager.getSecret('firebase_messaging_sender_id'),
        FIREBASE_APP_ID: await secretManager.getSecret('firebase_app_id'),

        // AWS Configuration (for production)
        AWS_REGION: process.env.AWS_REGION || 'us-east-1',
        AWS_S3_BUCKET: process.env.AWS_S3_BUCKET,

        // Monitoring Configuration
        SENTRY_DSN: await secretManager.getSecret('sentry_dsn'),
        ELASTICSEARCH_URL: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',

        // CORS Configuration
        CORS_ORIGINS: process.env.CORS_ORIGINS?.split(',').map(s => s.trim()) || [],
        CORS_ALLOW_NULL_ORIGIN: process.env.CORS_ALLOW_NULL_ORIGIN === 'true',

        // Development Configuration
        DEV_AUTH_BYPASS_ENABLED: process.env.DEV_AUTH_BYPASS_ENABLED === 'true',
        DEV_AUTH_BYPASS_SECRET: process.env.DEV_AUTH_BYPASS_SECRET,

        // Application Configuration
        DEFAULT_COUNTRY_CODE: process.env.DEFAULT_COUNTRY_CODE || '+91',
        MAX_LOGIN_ATTEMPTS: parseInt(process.env.MAX_LOGIN_ATTEMPTS) || 5,
        LOCKOUT_DURATION: parseInt(process.env.LOCKOUT_DURATION) || 15 * 60 * 1000, // 15 minutes

        // Rate Limiting Configuration
        RATE_LIMIT_WINDOW_MS: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
        RATE_LIMIT_MAX_REQUESTS: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
        AUTH_RATE_LIMIT_MAX_REQUESTS: parseInt(process.env.AUTH_RATE_LIMIT_MAX_REQUESTS) || 5,

        // File Upload Configuration
        MAX_FILE_SIZE: parseInt(process.env.MAX_FILE_SIZE) || 5 * 1024 * 1024, // 5MB
        ALLOWED_FILE_TYPES: process.env.ALLOWED_FILE_TYPES?.split(',') || ['image/jpeg', 'image/png', 'image/webp'],

        // Backup Configuration
        BACKUP_SCHEDULE: process.env.BACKUP_SCHEDULE || '0 2 * * *', // Daily at 2 AM
        BACKUP_RETENTION_DAYS: parseInt(process.env.BACKUP_RETENTION_DAYS) || 30,
        AWS_BACKUP_BUCKET: process.env.AWS_BACKUP_BUCKET,

        // Notification Configuration
        FCM_SERVER_KEY: await secretManager.getSecret('fcm_server_key'),
        NOTIFICATION_COOLDOWN_MS: parseInt(process.env.NOTIFICATION_COOLDOWN_MS) || 30000, // 30 seconds
        MAX_NOTIFICATIONS_PER_MINUTE: parseInt(process.env.MAX_NOTIFICATIONS_PER_MINUTE) || 20
      };

      // Validate required configuration
      this.validateConfig();

      this.isLoaded = true;
      logger.info('config_loaded_successfully', { 
        environment: this.config.NODE_ENV,
        port: this.config.PORT 
      });

      return this.config;
    } catch (error) {
      logger.error('config_loading_failed', { error: error.message });
      throw new Error(`Failed to load configuration: ${error.message}`);
    }
  }

  validateConfig() {
    const required = [
      'DATABASE_URL',
      'REDIS_URL',
      'JWT_ACCESS_SECRET',
      'JWT_REFRESH_SECRET',
      'OTP_HASH_SECRET'
    ];

    const missing = required.filter(key => !this.config[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required configuration: ${missing.join(', ')}`);
    }

    // Validate environment-specific requirements
    if (this.config.NODE_ENV === 'production') {
      const prodRequired = [
        'SENTRY_DSN',
        'FIREBASE_API_KEY',
        'GOOGLE_MAPS_API_KEY'
      ];

      const prodMissing = prodRequired.filter(key => !this.config[key]);
      if (prodMissing.length > 0) {
        logger.warn('production_config_missing', { missing: prodMissing });
      }
    }

    // Validate numeric values
    const numericValidation = {
      PORT: { min: 1, max: 65535 },
      MAX_LOGIN_ATTEMPTS: { min: 1, max: 10 },
      LOCKOUT_DURATION: { min: 60000, max: 3600000 }, // 1 minute to 1 hour
      RATE_LIMIT_WINDOW_MS: { min: 60000, max: 3600000 }, // 1 minute to 1 hour
      BACKUP_RETENTION_DAYS: { min: 1, max: 365 }
    };

    for (const [key, validation] of Object.entries(numericValidation)) {
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
