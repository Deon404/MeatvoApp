const express = require('express');
const asyncHandler = require('express-async-handler');
const { ok, fail } = require('../utils/response');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');
const {
  getSecurityStats,
  deviceService,
  sessionService,
  mfaService,
  otpSecurity,
  accountLockoutService,
  apiAbuseService,
  socketSecurity,
  jwtSecurity,
} = require('./services');

const router = express.Router();

/**
 * Get comprehensive security statistics
 */
router.get('/stats', asyncHandler(async (req, res) => {
  try {
    const stats = getSecurityStats();
    
    logger.info('security_stats_requested', {
      userId: req.user?.id,
      ip: req.ip
    });

    return ok(res, stats, 'Security statistics retrieved successfully');
  } catch (error) {
    logger.error('security_stats_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to retrieve security statistics');
  }
}));

/**
 * Get user's devices
 */
router.get('/devices', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const devices = await deviceService.getUserDevices(req.user.id);
    
    logger.info('user_devices_retrieved', {
      userId: req.user.id,
      deviceCount: devices.length
    });

    return ok(res, { devices }, 'Devices retrieved successfully');
  } catch (error) {
    logger.error('user_devices_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to retrieve devices');
  }
}));

/**
 * Trust a device
 */
router.post('/devices/:deviceId/trust', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const { deviceId } = req.params;
    const device = await deviceService.trustDevice(req.user.id, deviceId, req);
    
    logger.info('device_trusted', {
      userId: req.user.id,
      deviceId,
      ip: req.ip
    });

    return ok(res, { device }, 'Device trusted successfully');
  } catch (error) {
    logger.error('device_trust_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to trust device');
  }
}));

/**
 * Revoke a device
 */
router.delete('/devices/:deviceId', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const { deviceId } = req.params;
    const device = await deviceService.revokeDevice(req.user.id, deviceId);
    
    logger.info('device_revoked', {
      userId: req.user.id,
      deviceId,
      ip: req.ip
    });

    return ok(res, { device }, 'Device revoked successfully');
  } catch (error) {
    logger.error('device_revoke_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to revoke device');
  }
}));

/**
 * Get user's sessions
 */
router.get('/sessions', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const sessions = await sessionService.getUserSessions(req.user.id);
    
    logger.info('user_sessions_retrieved', {
      userId: req.user.id,
      sessionCount: sessions.length
    });

    return ok(res, { sessions }, 'Sessions retrieved successfully');
  } catch (error) {
    logger.error('user_sessions_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to retrieve sessions');
  }
}));

/**
 * Invalidate all user sessions
 */
router.post('/sessions/invalidate-all', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const invalidatedCount = await sessionService.invalidateAllUserSessions(req.user.id);
    
    logger.info('all_user_sessions_invalidated', {
      userId: req.user.id,
      invalidatedCount,
      ip: req.ip
    });

    return ok(res, { invalidatedCount }, 'All sessions invalidated successfully');
  } catch (error) {
    logger.error('session_invalidation_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to invalidate sessions');
  }
}));

/**
 * Get MFA status
 */
router.get('/mfa/status', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const status = mfaService.getMFAStatus(req.user);
    
    logger.info('mfa_status_retrieved', {
      userId: req.user.id,
      mfaEnabled: status.enabled
    });

    return ok(res, status, 'MFA status retrieved successfully');
  } catch (error) {
    logger.error('mfa_status_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to retrieve MFA status');
  }
}));

/**
 * Generate MFA backup codes
 */
router.post('/mfa/backup-codes', asyncHandler(async (req, res) => {
  try {
    if (!req.user) {
      return fail(res, 401, 'Authentication required');
    }

    const backupCodes = mfaService.generateBackupCodes(req.user.id);
    
    logger.info('mfa_backup_codes_generated', {
      userId: req.user.id,
      codeCount: backupCodes.length
    });

    return ok(res, { backupCodes }, 'Backup codes generated successfully');
  } catch (error) {
    logger.error('mfa_backup_codes_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to generate backup codes');
  }
}));

/**
 * Check if phone is blocked for OTP
 */
router.get('/otp/block-status/:phone', asyncHandler(async (req, res) => {
  try {
    const { phone } = req.params;
    const isBlocked = otpSecurity.isPhoneBlocked(phone);
    const remainingTime = otpSecurity.getPhoneBlockRemainingTime(phone);
    
    logger.info('otp_block_status_checked', {
      phone: otpSecurity.maskPhone(phone),
      isBlocked,
      remainingTime
    });

    return ok(res, { 
      isBlocked, 
      remainingTime,
      blockedUntil: isBlocked ? Date.now() + (remainingTime * 1000) : null
    }, 'OTP block status retrieved');
  } catch (error) {
    logger.error('otp_block_status_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to check OTP block status');
  }
}));

/**
 * Get account lockout status
 */
router.get('/account-lockout/status/:identifier/:type', asyncHandler(async (req, res) => {
  try {
    const { identifier, type } = req.params;
    const lockoutStatus = accountLockoutService.isAccountLocked(identifier, type);
    
    logger.info('account_lockout_status_checked', {
      type,
      identifier: accountLockoutService.maskIdentifier(identifier, type),
      locked: lockoutStatus.locked
    });

    return ok(res, lockoutStatus, 'Account lockout status retrieved');
  } catch (error) {
    logger.error('account_lockout_status_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to check account lockout status');
  }
}));

/**
 * Manual account lockout (admin only)
 */
router.post('/account-lockout/lock/:identifier/:type', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { identifier, type } = req.params;
    const { reason, duration } = req.body;
    const result = accountLockoutService.manualLockAccount(identifier, type, reason, duration);
    
    logger.warn('account_manually_locked', {
      type,
      identifier: accountLockoutService.maskIdentifier(identifier, type),
      reason,
      duration,
      adminId: req.user.id
    });

    return ok(res, result, 'Account locked successfully');
  } catch (error) {
    logger.error('manual_account_lock_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to lock account');
  }
}));

/**
 * Manual account unlock (admin only)
 */
router.post('/account-lockout/unlock/:identifier/:type', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { identifier, type } = req.params;
    const { reason } = req.body;
    const result = accountLockoutService.unlockAccount(identifier, type, reason);
    
    logger.info('account_manually_unlocked', {
      type,
      identifier: accountLockoutService.maskIdentifier(identifier, type),
      reason,
      adminId: req.user.id
    });

    return ok(res, { unlocked: result }, 'Account unlocked successfully');
  } catch (error) {
    logger.error('manual_account_unlock_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to unlock account');
  }
}));

/**
 * Get API abuse statistics (admin only)
 */
router.get('/api-abuse/stats', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const stats = apiAbuseService.getAbuseStats();
    
    logger.info('api_abuse_stats_requested', {
      adminId: req.user.id,
      ip: req.ip
    });

    return ok(res, stats, 'API abuse statistics retrieved successfully');
  } catch (error) {
    logger.error('api_abuse_stats_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to retrieve API abuse statistics');
  }
}));

/**
 * Block IP address (admin only)
 */
router.post('/api-abuse/block-ip/:ip', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { ip } = req.params;
    const { reason, abuseScore } = req.body;
    const result = apiAbuseService.blockIP(ip, reason, abuseScore);
    
    logger.warn('ip_manually_blocked', {
      ip,
      reason,
      abuseScore,
      adminId: req.user.id
    });

    return ok(res, { blocked: result }, 'IP blocked successfully');
  } catch (error) {
    logger.error('manual_ip_block_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to block IP');
  }
}));

/**
 * Unblock IP address (admin only)
 */
router.post('/api-abuse/unblock-ip/:ip', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { ip } = req.params;
    const { reason } = req.body;
    const result = apiAbuseService.unblockIP(ip, reason);
    
    logger.info('ip_manually_unblocked', {
      ip,
      reason,
      adminId: req.user.id
    });

    return ok(res, { unblocked: result }, 'IP unblocked successfully');
  } catch (error) {
    logger.error('manual_ip_unblock_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to unblock IP');
  }
}));

/**
 * Analyze request for abuse (admin only)
 */
router.post('/api-abuse/analyze', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { request } = req.body;
    const analysis = apiAbuseService.analyzeRequest(request);
    
    logger.info('request_abuse_analysis', {
      adminId: req.user.id,
      ip: request.ip,
      abuseScore: analysis.abuseScore,
      riskLevel: analysis.riskLevel
    });

    return ok(res, analysis, 'Request analysis completed');
  } catch (error) {
    logger.error('request_abuse_analysis_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to analyze request');
  }
}));

/**
 * Get socket security statistics (admin only)
 */
router.get('/socket/stats', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const stats = socketSecurity.getSecurityStats();
    
    logger.info('socket_security_stats_requested', {
      adminId: req.user.id,
      ip: req.ip
    });

    return ok(res, stats, 'Socket security statistics retrieved successfully');
  } catch (error) {
    logger.error('socket_security_stats_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to retrieve socket security statistics');
  }
}));

/**
 * Force disconnect user from sockets (admin only)
 */
router.post('/socket/disconnect-user/:userId', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { userId } = req.params;
    const { reason } = req.body;
    const result = socketSecurity.forceDisconnectUser(userId, reason);
    
    logger.warn('user_force_disconnected_from_sockets', {
      userId,
      reason,
      adminId: req.user.id
    });

    return ok(res, { disconnectedConnections: result }, 'User disconnected from sockets');
  } catch (error) {
    logger.error('force_socket_disconnect_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to disconnect user from sockets');
  }
}));

/**
 * Revoke all user tokens (admin only)
 */
router.post('/jwt/revoke-all/:userId', asyncHandler(async (req, res) => {
  try {
    if (!req.user || req.user.role !== 'admin') {
      return fail(res, 403, 'Admin access required');
    }

    const { userId } = req.params;
    const revokedCount = jwtSecurity.revokeAllUserTokens(userId);
    
    logger.warn('all_user_tokens_revoked', {
      targetUserId: userId,
      revokedCount,
      adminId: req.user.id
    });

    return ok(res, { revokedCount }, 'All user tokens revoked successfully');
  } catch (error) {
    logger.error('token_revocation_error', { error: error.message });
    sentry.captureException(error);
    return fail(res, 500, 'Failed to revoke user tokens');
  }
}));

module.exports = router;
