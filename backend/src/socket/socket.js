const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { query } = require('../db/postgres');
const socketSecurity = require('../security/socket.security');
const jwtSecurity = require('../security/jwt.security');

let io;

const getCorsOrigins = () =>
  (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

const initSocket = (httpServer) => {
  const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
  const allowNullOrigin =
    String(process.env.CORS_ALLOW_NULL_ORIGIN || '').toLowerCase() === 'true' || !isProd;
  const allowAnyOriginInDev = getCorsOrigins().length === 0 && !isProd;
  io = new Server(httpServer, {
    path: '/ws',
    cors: {
      origin(origin, cb) {
        const origins = getCorsOrigins();
        if (!origin || origin === 'null') {
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
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
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
      socket.join(`customer_${userId}`);
      console.log(`Customer ${userId} joined room`);
    });

    // Admin joins admin room
    socket.on('join_admin_room', () => {
      socket.join('admin_room');
      console.log('Admin joined admin room');
    });

    // Delivery partner joins their room
    socket.on('join_delivery_room', (userId) => {
      socket.join(`delivery_${userId}`);
      console.log(`Delivery partner ${userId} joined room`);
    });

    socket.on('disconnect', () => {
      console.log('Socket disconnected:', socket.id);
    });
  });

  return io;
};

const emitToUser = (userId, event, payload) => {
  if (!io) return;
  // Use secure broadcast with validation
  socketSecurity.secureBroadcastToUser(userId, event, payload);
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
