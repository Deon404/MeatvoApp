const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class SessionService {
  constructor() {
    this.sessions = new Map(); // In production, use Redis
    this.sessionExpiry = 24 * 60 * 60 * 1000; // 24 hours
    this.maxConcurrentSessions = 3; // Max sessions per user
  }

  /**
   * Create a new session
   */
  async createSession(userId, req, deviceInfo = null) {
    try {
      const sessionId = crypto.randomBytes(32).toString('hex');
      const timestamp = Date.now();
      
      const sessionData = {
        id: sessionId,
        userId,
        createdAt: timestamp,
        lastActivity: timestamp,
        ipAddress: req.ip || req.connection.remoteAddress || '',
        userAgent: req.get('User-Agent') || '',
        deviceFingerprint: deviceInfo?.fingerprint || null,
        deviceId: deviceInfo?.id || null,
        isActive: true,
        trusted: deviceInfo?.trusted || false
      };

      // Store session
      this.sessions.set(sessionId, sessionData);

      // Check if user has too many concurrent sessions
      await this.enforceSessionLimit(userId);

      logger.info('session_created', { 
        userId, 
        sessionId: sessionId.substring(0, 8) + '...',
        ipAddress: sessionData.ipAddress 
      });

      return sessionData;
    } catch (error) {
      logger.error('session_creation_failed', { error: error.message, userId });
      sentry.captureException(error, { userId });
      throw new Error('Failed to create session');
    }
  }

  /**
   * Get session by ID
   */
  async getSession(sessionId) {
    try {
      const session = this.sessions.get(sessionId);
      
      if (!session) {
        return null;
      }

      // Check if session has expired
      if (Date.now() - session.lastActivity > this.sessionExpiry) {
        this.invalidateSession(sessionId);
        return null;
      }

      // Update last activity
      session.lastActivity = Date.now();
      
      return session;
    } catch (error) {
      logger.error('session_retrieval_failed', { error: error.message, sessionId });
      return null;
    }
  }

  /**
   * Update session activity
   */
  async updateSessionActivity(sessionId, req) {
    try {
      const session = this.sessions.get(sessionId);
      
      if (!session) {
        return false;
      }

      session.lastActivity = Date.now();
      session.ipAddress = req.ip || session.ipAddress;
      
      return true;
    } catch (error) {
      logger.error('session_activity_update_failed', { error: error.message, sessionId });
      return false;
    }
  }

  /**
   * Invalidate a session
   */
  async invalidateSession(sessionId) {
    try {
      const session = this.sessions.get(sessionId);
      
      if (session) {
        session.isActive = false;
        session.invalidatedAt = Date.now();
        
        logger.info('session_invalidated', { 
          userId: session.userId,
          sessionId: sessionId.substring(0, 8) + '...' 
        });
      }

      this.sessions.delete(sessionId);
      return true;
    } catch (error) {
      logger.error('session_invalidation_failed', { error: error.message, sessionId });
      return false;
    }
  }

  /**
   * Invalidate all sessions for a user
   */
  async invalidateAllUserSessions(userId) {
    try {
      const invalidatedSessions = [];
      
      for (const [sessionId, session] of this.sessions.entries()) {
        if (session.userId === userId) {
          session.isActive = false;
          session.invalidatedAt = Date.now();
          invalidatedSessions.push(sessionId);
          this.sessions.delete(sessionId);
        }
      }

      logger.info('all_user_sessions_invalidated', { 
        userId,
        count: invalidatedSessions.length 
      });

      return invalidatedSessions.length;
    } catch (error) {
      logger.error('user_sessions_invalidation_failed', { error: error.message, userId });
      return 0;
    }
  }

  /**
   * Enforce session limit per user
   */
  async enforceSessionLimit(userId) {
    try {
      const userSessions = [];
      
      for (const [sessionId, session] of this.sessions.entries()) {
        if (session.userId === userId && session.isActive) {
          userSessions.push({ sessionId, session });
        }
      }

      // If user has too many sessions, invalidate the oldest ones
      if (userSessions.length > this.maxConcurrentSessions) {
        const sessionsToInvalidate = userSessions
          .sort((a, b) => a.session.lastActivity - b.session.lastActivity)
          .slice(0, userSessions.length - this.maxConcurrentSessions);

        for (const { sessionId } of sessionsToInvalidate) {
          await this.invalidateSession(sessionId);
        }

        logger.info('sessions_pruned_due_to_limit', { 
          userId,
          prunedCount: sessionsToInvalidate.length,
          remainingCount: this.maxConcurrentSessions 
        });
      }
    } catch (error) {
      logger.error('session_limit_enforcement_failed', { error: error.message, userId });
    }
  }

  /**
   * Get all active sessions for a user
   */
  async getUserSessions(userId) {
    try {
      const userSessions = [];
      
      for (const [sessionId, session] of this.sessions.entries()) {
        if (session.userId === userId && session.isActive) {
          userSessions.push({
            id: session.id,
            createdAt: session.createdAt,
            lastActivity: session.lastActivity,
            ipAddress: session.ipAddress,
            userAgent: session.userAgent,
            deviceId: session.deviceId,
            trusted: session.trusted
          });
        }
      }

      return userSessions.sort((a, b) => b.lastActivity - a.lastActivity);
    } catch (error) {
      logger.error('get_user_sessions_failed', { error: error.message, userId });
      return [];
    }
  }

  /**
   * Check if session is from trusted device
   */
  async isTrustedSession(sessionId) {
    try {
      const session = this.sessions.get(sessionId);
      return session ? session.trusted : false;
    } catch (error) {
      logger.error('trusted_session_check_failed', { error: error.message, sessionId });
      return false;
    }
  }

  /**
   * Clean up expired sessions
   */
  cleanupExpiredSessions() {
    try {
      const now = Date.now();
      for (const [sessionId, session] of this.sessions.entries()) {
        if (now - session.lastActivity > this.sessionExpiry) {
          this.sessions.delete(sessionId);
        }
      }
    } catch (error) {
      logger.error('session_cleanup_failed', { error: error.message });
    }
  }

  /**
   * Get session statistics
   */
  getSessionStats() {
    try {
      const stats = {
        totalSessions: this.sessions.size,
        activeSessions: 0,
        trustedSessions: 0,
        sessionsByUser: {}
      };

      for (const [sessionId, session] of this.sessions.entries()) {
        if (session.isActive) {
          stats.activeSessions++;
          
          if (session.trusted) {
            stats.trustedSessions++;
          }

          const userId = session.userId;
          stats.sessionsByUser[userId] = (stats.sessionsByUser[userId] || 0) + 1;
        }
      }

      return stats;
    } catch (error) {
      logger.error('session_stats_failed', { error: error.message });
      return {
        totalSessions: 0,
        activeSessions: 0,
        trustedSessions: 0,
        sessionsByUser: {}
      };
    }
  }
}

module.exports = new SessionService();
