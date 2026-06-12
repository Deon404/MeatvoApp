const express = require('express');
const { authenticateToken, requireRole } = require('../../middlewares/enhancedAuth.middleware');
const { body, validationResult } = require('express-validator');
const mfaService = require('./mfa.service');
const { logger } = require('../../utils/logger');
const { sentry } = require('../../utils/sentry');
const { ok, fail } = require('../../utils/response');

const router = express.Router();

// Validation middleware
const validateRequest = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return fail(res, 400, 'Validation failed', { issues: errors.array() });
  }
  next();
};

// Generate MFA setup data
router.post('/setup', 
  authenticateToken,
  requireRole(['customer', 'delivery', 'admin']),
  async (req, res) => {
    try {
      const user = req.user;
      
      // Check if MFA is already enabled
      if (mfaService.isMFAEnabled(user)) {
        return fail(res, 400, 'MFA is already enabled for this account', { code: 'MFA_ALREADY_ENABLED' });
      }

      const mfaData = await mfaService.generateMFAResponse(user);
      
      sentry.addBreadcrumb({
        message: 'MFA setup initiated',
        category: 'auth',
        level: 'info',
        data: { userId: user.id }
      });

      return ok(res, mfaData, 'MFA setup data generated');
    } catch (error) {
      logger.error('mfa_setup_route_error', { 
        error: error.message,
        userId: req.user?.id 
      });
      sentry.captureException(error, { userId: req.user?.id });
      return fail(res, 500, 'Failed to generate MFA setup data');
    }
  }
);

// Verify and enable MFA
router.post('/enable',
  authenticateToken,
  requireRole(['customer', 'delivery', 'admin']),
  [
    body('secret')
      .notEmpty()
      .withMessage('Secret is required')
      .isLength({ min: 32 })
      .withMessage('Invalid secret format'),
    body('token')
      .notEmpty()
      .withMessage('Token is required')
      .isNumeric()
      .withMessage('Token must be numeric')
      .isLength({ min: 6, max: 6 })
      .withMessage('Token must be 6 digits')
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { secret, token } = req.body;
      const user = req.user;

      // Validate the setup
      const isValid = mfaService.validateSetup(secret, token);
      
      if (!isValid) {
        return fail(res, 400, 'Invalid verification code. Please try again.', { code: 'MFA_INVALID' });
      }

      // Generate backup codes
      const backupCodes = mfaService.generateBackupCodes(user.id);

      // Enable MFA for user
      await mfaService.enableMFA(user.id, secret, backupCodes);

      sentry.addBreadcrumb({
        message: 'MFA enabled successfully',
        category: 'auth',
        level: 'info',
        data: { userId: user.id }
      });

      return ok(res, {
        backupCodes,
        instructions: 'Save these backup codes in a secure location. Each code can only be used once.',
      }, 'MFA enabled successfully');
    } catch (error) {
      logger.error('mfa_enable_route_error', { 
        error: error.message,
        userId: req.user?.id 
      });
      sentry.captureException(error, { userId: req.user?.id });
      return fail(res, 500, 'Failed to enable MFA');
    }
  }
);

// Verify MFA token (for login)
router.post('/verify',
  [
    body('token')
      .notEmpty()
      .withMessage('Token is required')
      .isNumeric()
      .withMessage('Token must be numeric')
      .isLength({ min: 6, max: 6 })
      .withMessage('Token must be 6 digits'),
    body('userId')
      .notEmpty()
      .withMessage('User ID is required')
      .isInt({ min: 1 })
      .withMessage('Invalid user ID')
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { token, userId } = req.body;

      const user = await mfaService.getUserMFA(Number(userId));

      if (!user || !mfaService.isMFAEnabled(user)) {
        return fail(res, 400, 'MFA is not enabled for this account', { code: 'MFA_NOT_ENABLED' });
      }

      // Verify the token
      const isValid = mfaService.verifyToken(token, user.mfaSecret);

      if (!isValid) {
        sentry.addBreadcrumb({
          message: 'MFA verification failed',
          category: 'auth',
          level: 'warning',
          data: { userId }
        });

        return fail(res, 400, 'Invalid verification code', { code: 'MFA_INVALID' });
      }

      sentry.addBreadcrumb({
        message: 'MFA verification successful',
        category: 'auth',
        level: 'info',
        data: { userId }
      });

      return ok(res, {}, 'MFA verification successful');
    } catch (error) {
      logger.error('mfa_verify_route_error', { 
        error: error.message,
        userId: req.body.userId 
      });
      sentry.captureException(error, { userId: req.body.userId });
      return fail(res, 500, 'Failed to verify MFA token');
    }
  }
);

// Verify backup code
router.post('/verify-backup-code',
  [
    body('code')
      .notEmpty()
      .withMessage('Backup code is required')
      .isLength({ min: 8, max: 9 })
      .withMessage('Invalid backup code format'),
    body('userId')
      .notEmpty()
      .withMessage('User ID is required')
      .isUUID()
      .withMessage('Invalid user ID')
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { code, userId } = req.body;

      const isValid = mfaService.verifyBackupCode(userId, code);

      if (!isValid) {
        sentry.addBreadcrumb({
          message: 'MFA backup code verification failed',
          category: 'auth',
          level: 'warning',
          data: { userId }
        });

        return fail(res, 400, 'Invalid backup code', { code: 'MFA_BACKUP_INVALID' });
      }

      const remainingCodes = mfaService.getRemainingBackupCodes(userId);

      sentry.addBreadcrumb({
        message: 'MFA backup code used successfully',
        category: 'auth',
        level: 'info',
        data: { userId, remainingCodes }
      });

      return ok(res, {
        remainingCodes,
        warning: remainingCodes <= 2 ? 'You have few backup codes remaining. Consider regenerating them.' : null,
      }, 'Backup code verified successfully');
    } catch (error) {
      logger.error('mfa_backup_code_verify_route_error', { 
        error: error.message,
        userId: req.body.userId 
      });
      sentry.captureException(error, { userId: req.body.userId });
      return fail(res, 500, 'Failed to verify backup code');
    }
  }
);

// Disable MFA
router.post('/disable',
  authenticateToken,
  requireRole(['customer', 'delivery', 'admin']),
  [
    body('token')
      .notEmpty()
      .withMessage('Token is required')
      .isNumeric()
      .withMessage('Token must be numeric')
      .isLength({ min: 6, max: 6 })
      .withMessage('Token must be 6 digits'),
    body('password')
      .notEmpty()
      .withMessage('Password is required')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters')
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { token, password } = req.body;
      const user = req.user;

      // In production, verify user password
      // const isPasswordValid = await bcrypt.compare(password, user.password);
      // if (!isPasswordValid) {
      //   return res.status(400).json({
      //     success: false,
      //     message: 'Invalid password'
      //   });
      // }

      // Verify MFA token
      if (mfaService.isMFAEnabled(user)) {
        const isValid = mfaService.verifyToken(token, user.mfaSecret);
        
        if (!isValid) {
          return fail(res, 400, 'Invalid MFA token', { code: 'MFA_INVALID' });
        }
      }

      // Disable MFA
      await mfaService.disableMFA(user.id);

      sentry.addBreadcrumb({
        message: 'MFA disabled',
        category: 'auth',
        level: 'warning',
        data: { userId: user.id }
      });

      return ok(res, {}, 'MFA disabled successfully');
    } catch (error) {
      logger.error('mfa_disable_route_error', { 
        error: error.message,
        userId: req.user?.id 
      });
      sentry.captureException(error, { userId: req.user?.id });
      return fail(res, 500, 'Failed to disable MFA');
    }
  }
);

// Get MFA status
router.get('/status',
  authenticateToken,
  requireRole(['customer', 'delivery', 'admin']),
  async (req, res) => {
    try {
      const user = req.user;
      const status = mfaService.getMFAStatus(user);

      return ok(res, status);
    } catch (error) {
      logger.error('mfa_status_route_error', { 
        error: error.message,
        userId: req.user?.id 
      });
      sentry.captureException(error, { userId: req.user?.id });
      return fail(res, 500, 'Failed to get MFA status');
    }
  }
);

// Regenerate backup codes
router.post('/regenerate-backup-codes',
  authenticateToken,
  requireRole(['customer', 'delivery', 'admin']),
  [
    body('token')
      .notEmpty()
      .withMessage('Token is required')
      .isNumeric()
      .withMessage('Token must be numeric')
      .isLength({ min: 6, max: 6 })
      .withMessage('Token must be 6 digits')
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { token } = req.body;
      const user = req.user;

      if (!mfaService.isMFAEnabled(user)) {
        return fail(res, 400, 'MFA is not enabled for this account', { code: 'MFA_NOT_ENABLED' });
      }

      // Verify current MFA token
      const isValid = mfaService.verifyToken(token, user.mfaSecret);
      
      if (!isValid) {
        return fail(res, 400, 'Invalid verification code', { code: 'MFA_INVALID' });
      }

      // Generate new backup codes
      const backupCodes = mfaService.regenerateBackupCodes(user.id);

      sentry.addBreadcrumb({
        message: 'MFA backup codes regenerated',
        category: 'auth',
        level: 'info',
        data: { userId: user.id, codeCount: backupCodes.length }
      });

      return ok(res, {
        backupCodes,
        warning: 'Save these new backup codes in a secure location. Old codes have been invalidated.',
      }, 'Backup codes regenerated successfully');
    } catch (error) {
      logger.error('mfa_regenerate_backup_codes_route_error', { 
        error: error.message,
        userId: req.user?.id 
      });
      sentry.captureException(error, { userId: req.user?.id });
      return fail(res, 500, 'Failed to regenerate backup codes');
    }
  }
);

module.exports = router;
