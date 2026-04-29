const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class SocketSecurity {
  constructor() {
    this.connections = new Map(); // In production, use Redis
    this.maxConnectionsPerUser = 3;
    this.connectionTimeout = 30 * 60 * 1000; // 30 minutes
    this.rateLimitWindow = 60 * 1000; // 1 minute
    this.maxMessagesPerWindow = 100;
    this.authenticateSocket = this.authenticateSocket.bind(this);
    this.rateLimitSocket = this.rateLimitSocket.bind(this);
    this.validateSocketMessage = this.validateSocketMessage.bind(this);
  }

  /**
   * Enhanced socket authentication
   */
  async authenticateSocket(socket, next) {
    try {
      const token = socket.handshake.auth?.token || 
                   socket.handshake.headers?.authorization?.replace(/^Bearer\s+/i, '');

      // Allow unauthenticated sockets for public endpoints only
      const publicPaths = ['/health', '/metrics', '/public'];
      const isPublicPath = publicPaths.some(path => socket.handshake.url?.startsWith(path));

      if (!token && !isPublicPath) {
        return next(new Error('Authentication required'));
      }

      if (!token && isPublicPath) {
        socket.user = null;
        socket.authType = 'public';
        return next();
      }

      // Verify JWT token
      const jwt = require('jsonwebtoken');
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
      
      if (!decoded || !decoded.id) {
        return next(new Error('Invalid token'));
      }

      // Get user from database
      const { query } = require('../db/postgres');
      const { rows } = await query('SELECT id, phone, name, role FROM users WHERE id = $1', [decoded.id]);
      const user = rows[0];

      if (!user) {
        return next(new Error('User not found'));
      }

      // Check connection limits
      const userConnections = this.getUserConnections(user.id);
      if (userConnections.length >= this.maxConnectionsPerUser) {
        // Disconnect oldest connection
        const oldestConnection = userConnections[0];
        oldestConnection.disconnect(true, 'Connection limit exceeded');
        
        logger.warn('socket_connection_limit_exceeded', {
          userId: user.id,
          connectionsCount: userConnections.length,
          maxConnections: this.maxConnectionsPerUser
        });
      }

      // Register connection
      this.registerConnection(socket, user);

      socket.user = user;
      socket.authType = 'authenticated';
      socket.connectionId = crypto.randomBytes(16).toString('hex');

      try {
        sentry.addBreadcrumb({
          message: 'Socket authenticated',
          category: 'socket',
          level: 'info',
          data: {
            userId: socket.user?.id,
            role: socket.user?.role,
            connectionId: socket.connectionId
          }
        });
      } catch (sentryError) {
        // Sentry not available, continue without it
        logger.debug('sentry_breadcrumb_failed', { error: sentryError.message });
      }

      next();
    } catch (error) {
      logger.error('socket_authentication_error', { 
        error: error.message,
        socketId: socket.id 
      });
      sentry.captureException(error, { socketId: socket.id });
      next(new Error('Authentication failed'));
    }
  }

  /**
   * Rate limiting for socket messages
   */
  rateLimitSocket(socket, next) {
    try {
      const userId = socket.user?.id;
      const connectionId = socket.connectionId;

      if (!userId) {
        return next(); // No rate limiting for public connections
      }

      const now = Date.now();
      const userKey = `rate_limit:${userId}`;
      const connectionKey = `rate_limit:${connectionId}`;

      // Get or create rate limit data
      let rateLimitData = this.connections.get(userKey) || {
        messages: [],
        lastReset: now
      };

      // Clean up old messages
      rateLimitData.messages = rateLimitData.messages.filter(
        timestamp => now - timestamp < this.rateLimitWindow
      );

      // Check rate limit
      if (rateLimitData.messages.length >= this.maxMessagesPerWindow) {
        logger.warn('socket_rate_limit_exceeded', {
          userId,
          connectionId,
          messageCount: rateLimitData.messages.length
        });

        socket.emit('rate_limit_exceeded', {
          message: 'Too many messages. Please wait.',
          retryAfter: Math.ceil(this.rateLimitWindow / 1000)
        });

        return next(new Error('Rate limit exceeded'));
      }

      // Add current message
      rateLimitData.messages.push(now);
      this.connections.set(userKey, rateLimitData);

      next();
    } catch (error) {
      logger.error('socket_rate_limit_error', { error: error.message });
      next(); // Don't block on rate limiting errors
    }
  }

  /**
   * Validate socket messages
   */
  validateSocketMessage(socket, eventName, data) {
    try {
      // Check message size
      const messageSize = JSON.stringify(data).length;
      const maxMessageSize = 1024 * 1024; // 1MB

      if (messageSize > maxMessageSize) {
        logger.warn('socket_message_too_large', {
          socketId: socket.id,
          eventName,
          messageSize
        });

        socket.emit('message_rejected', {
          reason: 'Message too large',
          maxSize: maxMessageSize
        });

        return false;
      }

      // Validate event names
      const allowedEventNames = [
        'ping', 'pong', 'join_room', 'leave_room',
        'order_update', 'location_update', 'chat_message',
        'notification', 'status_update'
      ];

      if (!allowedEventNames.includes(eventName)) {
        logger.warn('socket_invalid_event_name', {
          socketId: socket.id,
          eventName
        });

        socket.emit('message_rejected', {
          reason: 'Invalid event name',
          eventName
        });

        return false;
      }

      // Check for malicious content
      const maliciousPatterns = [
        /<script/i,
        /javascript:/i,
        /data:text\/html/i,
        /<iframe/i,
        /eval\s*\(/i
      ];

      const messageString = JSON.stringify(data);
      const isMalicious = maliciousPatterns.some(pattern => pattern.test(messageString));

      if (isMalicious) {
        logger.warn('socket_malicious_content_detected', {
          socketId: socket.id,
          eventName,
          userId: socket.user?.id
        });

        try {
        sentry.addBreadcrumb({
          message: 'Malicious socket content detected',
          category: 'security',
          level: 'warning',
          data: {
            socketId: socket.id,
            eventName,
            userId: socket.user?.id
          }
        });
      } catch (sentryError) {
        // Sentry not available, continue without it
        logger.debug('sentry_breadcrumb_failed', { error: sentryError.message });
      }

        socket.emit('message_rejected', {
          reason: 'Malicious content detected'
        });

        return false;
      }

      return true;
    } catch (error) {
      logger.error('socket_message_validation_error', { error: error.message });
      return false;
    }
  }

  /**
   * Register a new connection
   */
  registerConnection(socket, user) {
    try {
      const connectionData = {
        socket,
        user,
        connectionId: socket.connectionId,
        connectedAt: Date.now(),
        lastActivity: Date.now(),
        ip: socket.handshake.address,
        userAgent: socket.handshake.headers['user-agent'] || '',
        rooms: new Set()
      };

      this.connections.set(socket.connectionId, connectionData);

      // Add to user connections
      const userConnections = this.getUserConnections(user.id);
      userConnections.push(connectionData);

      logger.info('socket_connection_registered', {
        userId: user.id,
        connectionId: socket.connectionId,
        ip: connectionData.ip
      });

      // Set up connection timeout
      this.setupConnectionTimeout(socket);
    } catch (error) {
      logger.error('socket_connection_registration_error', { error: error.message });
    }
  }

  /**
   * Get all connections for a user
   */
  getUserConnections(userId) {
    const userConnections = [];
    
    for (const [connectionId, connectionData] of this.connections.entries()) {
      if (connectionData.user && connectionData.user.id === userId) {
        userConnections.push(connectionData);
      }
    }

    return userConnections;
  }

  /**
   * Set up connection timeout
   */
  setupConnectionTimeout(socket) {
    const timeout = setTimeout(() => {
      if (socket.connected) {
        logger.warn('socket_connection_timeout', {
          connectionId: socket.connectionId,
          userId: socket.user?.id
        });

        socket.disconnect(true, 'Connection timeout');
      }
    }, this.connectionTimeout);

    socket.on('disconnect', () => {
      clearTimeout(timeout);
    });

    socket.on('ping', () => {
      clearTimeout(timeout);
      this.setupConnectionTimeout(socket);
    });
  }

  /**
   * Handle socket disconnection
   */
  handleDisconnection(socket) {
    try {
      const connectionData = this.connections.get(socket.connectionId);
      
      if (connectionData) {
        logger.info('socket_connection_disconnected', {
          userId: connectionData.user?.id,
          connectionId: socket.connectionId,
          duration: Date.now() - connectionData.connectedAt
        });

        this.connections.delete(socket.connectionId);
      }
    } catch (error) {
      logger.error('socket_disconnection_error', { error: error.message });
    }
  }

  /**
   * Broadcast to user with security checks
   */
  secureBroadcastToUser(userId, eventName, data) {
    try {
      const userConnections = this.getUserConnections(userId);
      
      for (const connectionData of userConnections) {
        if (connectionData.socket.connected) {
          // Validate message before sending
          if (this.validateSocketMessage(connectionData.socket, eventName, data)) {
            connectionData.socket.emit(eventName, data);
            
            // Update last activity
            connectionData.lastActivity = Date.now();
          }
        }
      }
    } catch (error) {
      logger.error('secure_broadcast_error', { error: error.message, userId });
    }
  }

  /**
   * Get socket security statistics
   */
  getSecurityStats() {
    try {
      const stats = {
        totalConnections: this.connections.size,
        authenticatedConnections: 0,
        publicConnections: 0,
        connectionsByUser: {},
        averageConnectionDuration: 0
      };

      let totalDuration = 0;
      let connectionCount = 0;

      for (const [connectionId, connectionData] of this.connections.entries()) {
        if (connectionData.user) {
          stats.authenticatedConnections++;
          const userId = connectionData.user.id;
          stats.connectionsByUser[userId] = (stats.connectionsByUser[userId] || 0) + 1;
        } else {
          stats.publicConnections++;
        }

        const duration = Date.now() - connectionData.connectedAt;
        totalDuration += duration;
        connectionCount++;
      }

      if (connectionCount > 0) {
        stats.averageConnectionDuration = totalDuration / connectionCount;
      }

      return stats;
    } catch (error) {
      logger.error('socket_security_stats_error', { error: error.message });
      return {
        totalConnections: 0,
        authenticatedConnections: 0,
        publicConnections: 0,
        connectionsByUser: {},
        averageConnectionDuration: 0
      };
    }
  }

  /**
   * Clean up expired connections
   */
  cleanupExpiredConnections() {
    try {
      const now = Date.now();
      
      for (const [connectionId, connectionData] of this.connections.entries()) {
        if (now - connectionData.lastActivity > this.connectionTimeout) {
          if (connectionData.socket.connected) {
            connectionData.socket.disconnect(true, 'Connection expired');
          }
          this.connections.delete(connectionId);
        }
      }
    } catch (error) {
      logger.error('socket_cleanup_error', { error: error.message });
    }
  }

  /**
   * Force disconnect all user connections
   */
  forceDisconnectUser(userId, reason = 'Logged out') {
    try {
      const userConnections = this.getUserConnections(userId);
      
      for (const connectionData of userConnections) {
        if (connectionData.socket.connected) {
          connectionData.socket.disconnect(true, reason);
        }
      }

      logger.info('user_force_disconnected', { userId, reason, connectionsCount: userConnections.length });
    } catch (error) {
      logger.error('force_disconnect_error', { error: error.message, userId });
    }
  }
}

module.exports = new SocketSecurity();
