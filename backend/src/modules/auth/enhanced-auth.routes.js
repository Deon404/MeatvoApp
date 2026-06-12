const express = require('express');
const router = express.Router();

const { authenticateToken, requireRole } = require('../../middlewares/enhancedAuth.middleware');
const { protect } = require('../../middlewares/auth.middleware');
const { mfaRateLimiter } = require('../../middlewares/mfaRateLimiter');
const { validate } = require('../../middlewares/validate.middleware');
const { enableMfaSchema } = require('./auth.validation');
const mfaService = require('./mfa.service');
const { logger } = require('../../utils/logger');
const { ok, fail } = require('../../utils/response');

// Async middleware wrapper
const asyncMiddleware = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// MFA setup routes
router.post('/mfa/setup', asyncMiddleware(authenticateToken), requireRole(['customer', 'delivery', 'admin']), async (req, res) => {
  try {
    const mfaData = await mfaService.generateMFAResponse(req.user);
    return ok(res, mfaData, 'MFA setup data generated');
  } catch (error) {
    logger.error('mfa_setup_error', { error: error.message, userId: req.user?.id });
    return fail(res, 500, 'Failed to setup MFA');
  }
});

router.post('/mfa/enable', asyncMiddleware(authenticateToken), requireRole(['customer', 'delivery', 'admin']), validate(enableMfaSchema), async (req, res) => {
  try {
    const { secret, token } = req.body;
    const isValid = mfaService.validateSetup(secret, token);
    if (!isValid) {
      return fail(res, 400, 'Invalid MFA token', { code: 'MFA_INVALID' });
    }
    await mfaService.enableMFA(req.user.id, secret);
    return ok(res, {}, 'MFA enabled successfully');
  } catch (error) {
    logger.error('mfa_enable_error', { error: error.message, userId: req.user?.id });
    return fail(res, 500, 'Failed to enable MFA');
  }
});

const verifyMfa = async (req, res) => {
  try {
    const { token } = req.body;
    const user = await mfaService.getUserMFA(req.user.id);
    if (!user || !mfaService.isMFAEnabled(user)) {
      return fail(res, 400, 'MFA is not enabled for this account', { code: 'MFA_NOT_ENABLED' });
    }

    const isValid = mfaService.verifyToken(token, user.mfaSecret);
    return ok(res, { verified: isValid }, 'MFA verification complete');
  } catch (error) {
    return fail(res, 500, 'Verification failed');
  }
};

router.post('/mfa/verify', protect, mfaRateLimiter, verifyMfa);

router.post('/mfa/disable', asyncMiddleware(authenticateToken), requireRole(['customer', 'delivery', 'admin']), async (req, res) => {
  try {
    await mfaService.disableMFA(req.user.id);
    return ok(res, {}, 'MFA disabled');
  } catch (error) {
    logger.error('mfa_disable_error', { error: error.message, userId: req.user?.id });
    return fail(res, 500, 'Failed to disable MFA');
  }
});

router.get('/mfa/status', asyncMiddleware(authenticateToken), async (req, res) => {
  try {
    const status = mfaService.getMFAStatus(req.user);
    return ok(res, status);
  } catch (error) {
    logger.error('mfa_status_error', { error: error.message, userId: req.user?.id });
    return fail(res, 500, 'Failed to get MFA status');
  }
});

module.exports = router;
