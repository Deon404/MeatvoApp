const router = require('express').Router();
const { authenticateToken } = require('../../middlewares/enhancedAuth.middleware');
const {
  getAdminFirebaseConfig,
  getDeliveryFirebaseConfig,
  getCustomerFirebaseConfig
} = require('./firebase.controller');

// Admin Firebase configuration endpoint
router.get('/admin/firebase-config', authenticateToken, getAdminFirebaseConfig);

// Delivery Firebase configuration endpoint
router.get('/delivery/firebase-config', authenticateToken, getDeliveryFirebaseConfig);

// Customer Firebase configuration endpoint
router.get('/customer/firebase-config', authenticateToken, getCustomerFirebaseConfig);

module.exports = router;
