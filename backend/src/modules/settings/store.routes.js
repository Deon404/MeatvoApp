/**
 * store.routes.js
 * Public store info + delivery zone check endpoints.
 * Mounted at: /api/store
 */
const express = require('express');
const router = express.Router();

const { getStoreStatus, checkDelivery } = require('../settings/settings.controller');

// Public routes — no auth required
router.get('/status', getStoreStatus);
router.post('/check-delivery', checkDelivery);

module.exports = router;
