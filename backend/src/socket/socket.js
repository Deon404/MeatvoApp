const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { query } = require('../db/postgres');
const socketSecurity = require('../security/socket.security');
const jwtSecurity = require('../security/jwt.security');
const { logger } = require('../utils/logger');
const { updateRiderLocation, verifyRiderAssignedToOrder } = require('../services/tracking.service');

let io;

const getCorsOrigins = () =>
  (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

const initSocket = (httpServer) => {
  const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
  const allowNullOrigin = isProd
    ? String(process.env.CORS_ALLOW_NULL_ORIGIN || 'false').toLowerCase() === 'true'
    : String(process.env.CORS_ALLOW_NULL_ORIGIN || 'true').toLowerCase() === 'true';
  const allowAnyOriginInDev = getCorsOrigins().length === 0 && !isProd;
  io = new Server(httpServer, {
    path: '/ws',
    pingInterval: 25000,
    pingTimeout: 60000,
    cors: {
      origin(origin, cb) {
        const origins = getCorsOrigins();
        // Native mobile clients (Flutter) omit Origin; JWT auth protects the handshake.
        if (!origin) return cb(null, true);
        if (origin === 'null') {
          if (allowNullOrigin) return cb(null, true);
          return cb(new Error('CORS blocked'), false);
        }
        if (allowAnyOriginInDev) return cb(null, true);
        if (origins.includes(origin)) return cb(null, true);
        return cb(new Error('CORS blocked'), false);
      },
      credentials: true,
    },
  });

  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('Authentication token required'));
    }
    
    try {
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
        issuer: 'meatvo-app',
        audience: 'meatvo-users',
        algorithms: ['HS256'],
      });
      if (decoded.type !== 'access') return next(new Error('Invalid token type'));
      const userId = Number(decoded?.id);
      if (!userId) return next(new Error('Invalid token'));

      const { rows } = await query(
        'SELECT id, role, phone, name FROM users WHERE id = $1',
        [userId]
      );
      const user = rows[0];
      if (!user) return next(new Error('User not found'));

      socket.userId = Number(user.id);
      socket.userRole = user.role;
      socket.user = user;
      
      // Rate limiting for socket connections
      await socketSecurity.rateLimitSocket(socket, next);

      socket.join(`user:${socket.user.id}`);
      socket.join(`role:${socket.user.role}`);
      socket.join('public');

      return next();
    } catch (err) {
      return next(new Error('Authentication failed'));
    }
  });

  io.on('connection', (socket) => {
    socket.on('ping', (cb) => {
      if (typeof cb === 'function') cb({ ok: true, user: socket.user || null });
    });

    // Customer joins their personal room
    socket.on('join_customer_room', (userId) => {
      const requestedId = Number(userId);
      if (!Number.isFinite(requestedId) || requestedId !== socket.userId) {
        logger.warn('socket_customer_room_denied', {
          requestedId: userId,
          socketUserId: socket.userId,
        });
        return;
      }
      socket.join(`customer_${requestedId}`);
      logger.debug('socket_customer_joined_room', { userId: requestedId });
    });

    // Admin joins admin room (canonical + legacy)
    socket.on('join_admin_room', () => {
      if (socket.userRole !== 'admin') return;
      socket.join('admin_room');
      socket.join('admin:orders');
      logger.debug('socket_admin_joined_room', { socketId: socket.id });
    });

    // Kitchen staff joins staff room (canonical + legacy)
    socket.on('join_staff_room', () => {
      if (socket.userRole !== 'staff') return;
      socket.join('staff_room');
      socket.join('staff:orders');
      logger.debug('socket_staff_joined_room', { socketId: socket.id });
    });

    // Customer joins order-specific tracking room
    socket.on('join_order_room', async (orderId) => {
      const numericOrderId = Number(orderId);
      if (!Number.isFinite(numericOrderId)) return;

      const { rows } = await query(
        'SELECT customer_id FROM orders WHERE id = $1',
        [numericOrderId]
      );
      const order = rows[0];
      if (!order) return;

      const role = String(socket.userRole || '').toLowerCase();
      if (role === 'customer' && Number(order.customer_id) !== socket.userId) {
        logger.warn('socket_order_room_denied', {
          orderId: numericOrderId,
          userId: socket.userId,
        });
        return;
      }
      if (!['customer', 'admin', 'staff'].includes(role)) return;

      socket.join(`order:${numericOrderId}`);
      logger.debug('socket_order_room_joined', {
        orderId: numericOrderId,
        userId: socket.userId,
        role,
      });
    });

    // Delivery partner joins their room
    socket.on('join_delivery_room', () => {
      const role = String(socket.userRole || '').toLowerCase();
      if (!['rider', 'delivery', 'delivery_partner'].includes(role)) {
        logger.warn('socket_delivery_room_denied', { userId: socket.userId, role });
        return;
      }
      socket.join(`delivery_${socket.userId}`);
      socket.join(`rider:${socket.userId}`);
      logger.debug('socket_delivery_joined_room', { userId: socket.userId });
    });

    // Rider live location via socket (Flutter rider_location_service.dart)
    socket.on('rider_location', async (data) => {
      try {
        const role = String(socket.userRole || '').toLowerCase();
        if (!['rider', 'delivery', 'delivery_partner'].includes(role)) {
          logger.warn('socket_rider_location_denied', {
            userId: socket.userId,
            role,
          });
          return;
        }

        let orderId = data?.orderId != null ? Number(data.orderId) : null;
        const lat = Number(data?.lat);
        const lng = Number(data?.lng);

        if (Number.isFinite(orderId)) {
          const assigned = await verifyRiderAssignedToOrder(socket.userId, orderId);
          if (!assigned) {
            logger.warn('socket_rider_location_unassigned_order', {
              userId: socket.userId,
              orderId,
            });
            orderId = null;
          }
        }

        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          logger.warn('socket_rider_location_invalid_coords', {
            userId: socket.userId,
            data,
          });
          return;
        }

        await updateRiderLocation({
          riderUserId: socket.userId,
          lat,
          lng,
          orderId: Number.isFinite(orderId) ? orderId : null,
          io,
        });
      } catch (err) {
        logger.error('socket_rider_location_failed', {
          error: err.message,
          userId: socket.userId,
        });
      }
    });

    socket.on('disconnect', (reason) => {
      logger.debug('socket_disconnected', {
        socketId: socket.id,
        userId: socket.userId,
        reason,
      });
    });
  });

  return io;
};

const emitToUser = (userId, event, payload) => {
  if (!io) return;
  // Emit directly to the user's personal room (sockets join 'user:{id}' on connect)
  io.to(`user:${userId}`).emit(event, payload);
};

const emitToRole = (role, event, payload) => {
  if (!io) return;
  io.to(`role:${role}`).emit(event, payload);
};

const emitToAll = (event, payload) => {
  if (!io) return;
  io.to('public').emit(event, payload);
};

module.exports = {
  initSocket,
  emitToUser,
  emitToRole,
  emitToAll,
};
