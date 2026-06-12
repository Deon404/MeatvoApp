const asyncHandler = require('express-async-handler');
const { ok, fail } = require('../../utils/response');
const { logger } = require('../../utils/logger');

// Get Firebase configuration for admin panel
const getAdminFirebaseConfig = asyncHandler(async (req, res) => {
  try {
    // Only authenticated admin users can get Firebase config
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    // Return Firebase configuration from environment variables
    const config = {
      apiKey: process.env.FIREBASE_API_KEY,
      authDomain: process.env.FIREBASE_AUTH_DOMAIN,
      projectId: process.env.FIREBASE_PROJECT_ID,
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
      messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
      appId: process.env.FIREBASE_APP_ID,
      measurementId: process.env.FIREBASE_MEASUREMENT_ID,
      vapidKey: process.env.FIREBASE_VAPID_KEY,
    };

    // Validate config
    if (!config.apiKey || !config.projectId || !config.messagingSenderId) {
      logger.warn('Firebase configuration incomplete', { 
        hasApiKey: !!config.apiKey,
        hasProjectId: !!config.projectId,
        hasSenderId: !!config.messagingSenderId
      });
      return fail(res, 500, 'Firebase configuration incomplete');
    }

    return ok(res, config, 'Firebase configuration retrieved');
  } catch (error) {
    logger.error('Error getting admin Firebase config', { error: error.message });
    return fail(res, 500, 'Internal server error');
  }
});

// Get Firebase configuration for delivery partners
const getDeliveryFirebaseConfig = asyncHandler(async (req, res) => {
  try {
    // Only authenticated delivery users can get Firebase config
    if (!req.user || req.user.role !== 'delivery') {
      return fail(res, 403, 'Delivery access required');
    }

    // Return Firebase configuration from environment variables
    const config = {
      apiKey: process.env.FIREBASE_API_KEY,
      authDomain: process.env.FIREBASE_AUTH_DOMAIN,
      projectId: process.env.FIREBASE_PROJECT_ID,
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
      messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
      appId: process.env.FIREBASE_APP_ID,
      measurementId: process.env.FIREBASE_MEASUREMENT_ID,
      vapidKey: process.env.FIREBASE_VAPID_KEY,
    };

    // Validate config
    if (!config.apiKey || !config.projectId || !config.messagingSenderId) {
      logger.warn('Firebase configuration incomplete', { 
        hasApiKey: !!config.apiKey,
        hasProjectId: !!config.projectId,
        hasSenderId: !!config.messagingSenderId
      });
      return fail(res, 500, 'Firebase configuration incomplete');
    }

    return ok(res, config, 'Firebase configuration retrieved');
  } catch (error) {
    logger.error('Error getting delivery Firebase config', { error: error.message });
    return fail(res, 500, 'Internal server error');
  }
});

// Get Firebase configuration for customers
const getCustomerFirebaseConfig = asyncHandler(async (req, res) => {
  try {
    // Only authenticated customers can get Firebase config
    if (!req.user || req.user.role !== 'customer') {
      return fail(res, 403, 'Customer access required');
    }

    // Return Firebase configuration from environment variables
    const config = {
      apiKey: process.env.FIREBASE_API_KEY,
      authDomain: process.env.FIREBASE_AUTH_DOMAIN,
      projectId: process.env.FIREBASE_PROJECT_ID,
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
      messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
      appId: process.env.FIREBASE_APP_ID,
      measurementId: process.env.FIREBASE_MEASUREMENT_ID,
      vapidKey: process.env.FIREBASE_VAPID_KEY,
    };

    // Validate config
    if (!config.apiKey || !config.projectId || !config.messagingSenderId) {
      logger.warn('Firebase configuration incomplete', { 
        hasApiKey: !!config.apiKey,
        hasProjectId: !!config.projectId,
        hasSenderId: !!config.messagingSenderId
      });
      return fail(res, 500, 'Firebase configuration incomplete');
    }

    return ok(res, config, 'Firebase configuration retrieved');
  } catch (error) {
    logger.error('Error getting customer Firebase config', { error: error.message });
    return fail(res, 500, 'Internal server error');
  }
});

module.exports = {
  getAdminFirebaseConfig,
  getDeliveryFirebaseConfig,
  getCustomerFirebaseConfig
};
