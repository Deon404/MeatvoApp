const { SSMClient, GetParameterCommand, PutParameterCommand } = require('@aws-sdk/client-ssm');
const { logger } = require('../../utils/logger');

class SecretManager {
  constructor() {
    this.client = null;
    this.cache = new Map();
    this.cacheExpiry = new Map();
    this.CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  }

  initialize() {
    if (process.env.NODE_ENV === 'production') {
      this.client = new SSMClient({ 
        region: process.env.AWS_REGION || 'us-east-1',
        ...(process.env.AWS_ACCESS_KEY_ID && {
          credentials: {
            accessKeyId: process.env.AWS_ACCESS_KEY_ID,
            secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
          }
        })
      });
      logger.info('secret_manager_initialized', { provider: 'aws-ssm' });
    } else {
      logger.info('secret_manager_dev_mode', { provider: 'environment' });
    }
  }

  async getSecret(secretName) {
    // Check cache first
    const cached = this.cache.get(secretName);
    const expiry = this.cacheExpiry.get(secretName);
    
    if (cached && expiry && Date.now() < expiry) {
      return cached;
    }

    try {
      if (this.client) {
        // Production: Use AWS Parameter Store
        const command = new GetParameterCommand({
          Name: `/meatvo/${secretName}`,
          WithDecryption: true
        });
        
        const response = await this.client.send(command);
        const secret = response.Parameter.Value;
        
        // Cache the secret
        this.cache.set(secretName, secret);
        this.cacheExpiry.set(secretName, Date.now() + this.CACHE_TTL);
        
        logger.debug('secret_retrieved', { name: secretName, source: 'aws-ssm' });
        return secret;
      } else {
        // Development: Use environment variables
        const envVarName = secretName.toUpperCase().replace(/[^A-Z0-9_]/g, '_');
        const secret = process.env[envVarName];
        
        if (!secret) {
          throw new Error(`Secret ${secretName} not found in environment variables`);
        }
        
        logger.debug('secret_retrieved', { name: secretName, source: 'environment' });
        return secret;
      }
    } catch (error) {
      logger.error('secret_retrieval_failed', { 
        name: secretName, 
        error: error.message 
      });
      throw new Error(`Failed to retrieve secret ${secretName}: ${error.message}`);
    }
  }

  async setSecret(secretName, value, description = '') {
    try {
      if (this.client) {
        const command = new PutParameterCommand({
          Name: `/meatvo/${secretName}`,
          Value: value,
          Type: 'SecureString',
          Description: description,
          Overwrite: true
        });
        
        await this.client.send(command);
        
        // Update cache
        this.cache.set(secretName, value);
        this.cacheExpiry.set(secretName, Date.now() + this.CACHE_TTL);
        
        logger.info('secret_stored', { name: secretName, source: 'aws-ssm' });
      } else {
        logger.warn('secret_storage_dev_mode', { 
          name: secretName, 
          message: 'Secrets not stored in development mode' 
        });
      }
    } catch (error) {
      logger.error('secret_storage_failed', { 
        name: secretName, 
        error: error.message 
      });
      throw error;
    }
  }

  clearCache(secretName = null) {
    if (secretName) {
      this.cache.delete(secretName);
      this.cacheExpiry.delete(secretName);
    } else {
      this.cache.clear();
      this.cacheExpiry.clear();
    }
    logger.debug('secret_cache_cleared', { name: secretName || 'all' });
  }

  // Batch secret retrieval for startup
  async getRequiredSecrets() {
    const requiredSecrets = [
      'database_url',
      'redis_url',
      'jwt_access_secret',
      'jwt_refresh_secret',
      'otp_hash_secret',
      'msg91_api_key',
      'cashfree_secret_key',
      'google_maps_api_key'
    ];

    const secrets = {};
    const errors = [];

    for (const secretName of requiredSecrets) {
      try {
        secrets[secretName] = await this.getSecret(secretName);
      } catch (error) {
        errors.push({ secret: secretName, error: error.message });
      }
    }

    if (errors.length > 0) {
      logger.error('required_secrets_missing', { errors });
      throw new Error(`Missing required secrets: ${errors.map(e => e.secret).join(', ')}`);
    }

    return secrets;
  }
}

module.exports = new SecretManager();
