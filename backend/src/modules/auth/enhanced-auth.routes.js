const express = require('express');
const router = express.Router();

const { authenticateToken, requireRole } = require('../../middlewares/enhancedAuth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const mfaService = require('./mfa.service');
const { logger } = require('../../utils/logger');

// Async middleware wrapper
const asyncMiddleware = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// MFA setup routes
router.post('/mfa/setup', asyncMiddleware(authenticateToken), requireRole(['customer', 'delivery', 'admin']), async (req, res) => {
  try {
    const mfaData = await mfaService.generateMFAResponse(req.user);
    res.json({ success: true, data: mfaData });
  } catch (error) {
    logger.error('mfa_setup_error', { error: error.message, userId: req.user?.id });
    res.status(500).json({ success: false, message: 'Failed to setup MFA' });
  }
});

router.post('/mfa/enable', asyncMiddleware(authenticateToken), requireRole(['customer', 'delivery', 'admin']), async (req, res) => {
  try {
    const { secret, token } = req.body;
    const isValid = mfaService.validateSetup(secret, token);
    if (!isValid) {
      return res.status(400).json({ success: false, message: 'Invalid MFA token' });
    }
    await mfaService.enableMFA(req.user.id, secret);
    res.json({ success: true, message: 'MFA enabled successfully' });
  } catch (error) {
    logger.error('mfa_enable_error', { error: error.message, userId: req.user?.id });
    res.status(500).json({ success: false, message: 'Failed to enable MFA' });
  }
});

router.post('/mfa/verify', async (req, res) => {
  try {
    const { token, userId } = req.body;
    const isValid = mfaService.verifyToken(token, 'demo_secret'); // Get from DB
    
    res.json({ success: true, verified: isValid });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

router.post('/mfa/disable', asyncMiddleware(authenticateToken), requireRole(['customer', 'delivery', 'admin']), async (req, res) => {
  try {
    await mfaService.disableMFA(req.user.id);
    res.json({ success: true, message: 'MFA disabled' });
  } catch (error) {
    logger.error('mfa_disable_error', { error: error.message, userId: req.user?.id });
    res.status(500).json({ success: false, message: 'Failed to disable MFA' });
  }
});

router.get('/mfa/status', asyncMiddleware(authenticateToken), async (req, res) => {
  try {
    const status = mfaService.getMFAStatus(req.user);
    res.json({ success: true, data: status });
  } catch (error) {
    logger.error('mfa_status_error', { error: error.message, userId: req.user?.id });
    res.status(500).json({ success: false, message: 'Failed to get MFA status' });
  }
});

module.exports = router;
