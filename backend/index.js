require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const hpp = require('hpp');
const path = require('path');

const { query } = require('./src/db/postgres');
const authRoutes = require('./src/modules/auth/auth.routes');
const productsRoutes = require('./src/modules/products/products.routes');
const categoriesRoutes = require('./src/modules/categories/categories.routes');
const ordersRoutes = require('./src/modules/orders/orders.routes');
const couponsRoutes = require('./src/modules/coupons/coupons.routes');
const bannersRoutes = require('./src/modules/banners/banners.routes');
const catalogRoutes = require('./src/modules/catalog/catalog.routes');
const cartRoutes = require('./src/modules/cart/cart.routes');
const usersRoutes = require('./src/modules/users/users.routes');
const addressesRoutes = require('./src/modules/addresses/addresses.routes');
const settingsRoutes = require('./src/modules/settings/settings.routes');
const firebaseRoutes = require('./src/modules/firebase/firebase.routes');
const paymentsRoutes = require('./src/modules/payments/payments.routes');
const adminRoutes = require('./src/modules/admin/admin.routes');
const deliveryRoutes = require('./src/modules/delivery/delivery.routes');
const storeRoutes = require('./src/modules/settings/store.routes');
const { errorHandler } = require('./src/middlewares/error.middleware');
const { requestLogger } = require('./src/middlewares/requestLogger.middleware');
const { apiRateLimiter, authIpRateLimiter } = require('./src/middlewares/rateLimiter');
const { logger } = require('./src/utils/logger');
const { ensureSchema } = require('./src/db/ensureSchema');

const app = express();

if (String(process.env.TRUST_PROXY || '').toLowerCase() === 'true') {
  app.set('trust proxy', 1);
}

// Fix CSP - Replace helmet default with custom config
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com', 'https://www.gstatic.com', 'https://unpkg.com'],
        scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", 'https://www.gstatic.com', 'https://*.firebaseio.com', 'https://*.googleapis.com', 'https://unpkg.com', 'https://cdn.jsdelivr.net'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com', 'https://www.gstatic.com'],
        imgSrc: ["'self'", 'data:', 'https:', 'http:'],
        connectSrc: ["'self'", 'ws:', 'wss:', 'http://localhost:8080', 'http://127.0.0.1:8080', 'https://*.googleapis.com', 'https://www.gstatic.com', 'https://*.firebaseio.com', 'https://fcm.googleapis.com'],
        manifestSrc: ["'self'"],
      },
    },
  })
);

app.use(hpp());

// HTTPS enforcement in production
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.header('x-forwarded-proto') !== 'https') {
      return res.redirect(301, `https://${req.header('host')}${req.url}`);
    }
    next();
  });
}

// Serve static files from project root
app.use(express.static(path.join(__dirname, '../')));

// Serve public folder for service worker
app.use(express.static(path.join(__dirname, '../public')));

app.use(express.json({ limit: '1mb' }));
app.use(requestLogger);
app.use('/api', apiRateLimiter);

// Secure CORS Configuration
const corsOrigins = (() => {
  const envOrigins = process.env.CORS_ALLOWED_ORIGINS;
  if (envOrigins) {
    return envOrigins.split(',').map(o => o.trim()).filter(Boolean);
  }
  // Default origins based on environment
  if (process.env.NODE_ENV === 'production') {
    return ['https://meatvo.app', 'https://www.meatvo.app'];
  }
  // Development - allow common local dev origins
  return [
    'http://localhost:3000',
    'http://localhost:8080',
    'http://localhost:8081',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8080',
    'http://127.0.0.1:8081',
    null // Allow requests with no origin (mobile apps, curl, etc.)
  ];
})();

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);

    // Check if origin is allowed
    if (corsOrigins.includes(origin)) {
      return callback(null, true);
    }

    // In development, log blocked origins for debugging
    if (process.env.NODE_ENV !== 'production') {
      console.warn(`⚠️ CORS blocked origin: ${origin}`);
      console.warn(`Allowed origins: ${corsOrigins.join(', ')}`);
      return callback(null, true); // Still allow in dev for convenience
    }

    // In production, reject unauthorized origins
    logger.warn('cors_blocked', { origin, allowedOrigins: corsOrigins });
    callback(new Error(`Origin ${origin} not allowed by CORS`));
  },
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "Accept", "X-CSRF-Token"],
  credentials: true,
  maxAge: 86400 // 24 hours
}));

app.get('/', (req, res) => {
  res.redirect('/customer/');
});

app.get('/health', async (req, res, next) => {
  try {
    await query('SELECT 1');
    res.json({
      status: 'ok',
      db: 'connected',
      uptime: Math.floor(process.uptime())
    });
  } catch (err) {
    res.status(503).json({
      status: 'error',
      db: 'disconnected',
      uptime: Math.floor(process.uptime())
    });
  }
});

// API routes - using modular endpoints
app.use('/api/auth', authIpRateLimiter, authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/addresses', addressesRoutes);
app.use('/api/v1/addresses', addressesRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/products', productsRoutes);
app.use('/api/categories', categoriesRoutes);
app.use('/api/v1/products', productsRoutes);
app.use('/api/v1/categories', categoriesRoutes);
app.use('/api/orders', ordersRoutes);
app.use('/api/v1/orders', ordersRoutes);
app.use('/api/coupons', couponsRoutes);
app.use('/api/admin/coupons', couponsRoutes);
app.use('/api/v1/admin/coupons', couponsRoutes);
app.use('/api/banners', bannersRoutes);
app.use('/api/payments', paymentsRoutes);
app.use('/api/v1/payments', paymentsRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/delivery', deliveryRoutes);
app.use('/api/v1/delivery', deliveryRoutes);
app.use('/api/firebase', firebaseRoutes);
app.use('/api/store', storeRoutes);   // Public: /status, /check-delivery

// SPA fallback routes - AFTER API routes
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, '../admin/admin.html'));
});

app.get('/customer', (req, res) => {
  res.sendFile(path.join(__dirname, '../customer/index.html'));
});

app.get('/delivery', (req, res) => {
  res.sendFile(path.join(__dirname, '../delivery/index.html'));
});

// Handle SPA routes with regex
app.get(/\/admin\/.*/, (req, res) => {
  res.sendFile(path.join(__dirname, '../admin/admin.html'));
});

app.get(/\/customer\/.*/, (req, res) => {
  res.sendFile(path.join(__dirname, '../customer/index.html'));
});

app.get(/\/delivery\/.*/, (req, res) => {
  res.sendFile(path.join(__dirname, '../delivery/index.html'));
});

app.use(errorHandler);

const PORT = Number(process.env.PORT || 8081);
const server = http.createServer(app);
const socketIo = require('./src/socket/socket').initSocket(server);

// Make io available globally for controllers
app.set('io', socketIo);

(async () => {
  try {
    await ensureSchema();
  } catch (err) {
    logger.error('schema_ensure_fatal', { message: err?.message, stack: err?.stack });
  }

  server.listen(PORT, () => {
    logger.info('server_started', { port: PORT });
  }).on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      logger.error('port_in_use', { port: PORT, message: `Port ${PORT} is already in use` });
      console.error(`❌ Port ${PORT} is already in use. Please:\n`);
      console.error(`1. Kill the process using port ${PORT}:`);
      console.error(`   netstat -ano | findstr :${PORT}`);
      console.error(`   taskkill /F /PID <PID>`);
      console.error(`2. Or use a different port: PORT=8082 npm run start:all`);
      process.exit(1);
    } else {
      logger.error('server_error', { message: err?.message, stack: err?.stack });
      process.exit(1);
    }
  });
})();