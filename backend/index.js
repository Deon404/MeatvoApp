require('dotenv').config();
const { validateEnv } = require('./src/config/validateEnv');
validateEnv();

const sentry = require('./src/utils/sentry');
sentry.initialize();

const http = require('http');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const hpp = require('hpp');
const fs = require('fs');
const path = require('path');

const { query, pool } = require('./src/db/postgres');
const { ok, fail } = require('./src/utils/response');
const authRoutes = require('./src/modules/auth/auth.routes');
const productsRoutes = require('./src/modules/products/products.routes');
const categoriesRoutes = require('./src/modules/categories/categories.routes');
const ordersRoutes = require('./src/modules/orders/orders.routes');
const enhancedOrdersRoutes = require('./src/modules/orders/enhancedOrders.routes');
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
const healthRoutes = require('./src/routes/health');
const debugRoutes = require('./src/routes/debug.routes');
const { router: metricsRouter, collectMetrics } = require('./src/routes/metrics');
const { errorHandler } = require('./src/middlewares/error.middleware');
const { requestLogger } = require('./src/middlewares/requestLogger.middleware');
const { apiRateLimiter, authIpRateLimiter } = require('./src/middlewares/rateLimiter');
const { logger } = require('./src/utils/logger');
const { ensureSchema } = require('./src/db/ensureSchema');
const { initializeSecurity } = require('./src/security');
const { adminOnly } = require('./src/middlewares/adminOnlyIp.middleware');

const app = express();

if (String(process.env.TRUST_PROXY || '').toLowerCase() === 'true') {
  app.set('trust proxy', 1);
}

const allowedOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim())
  : ['http://localhost:3000'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
}));

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
        connectSrc: [
          "'self'",
          'ws:',
          'wss:',
          ...(process.env.NODE_ENV !== 'production'
            ? ['http://localhost:8080', 'http://127.0.0.1:8080']
            : []),
          ...(process.env.CORS_ORIGINS
            ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
            : []),
          'https://*.googleapis.com',
          'https://www.gstatic.com',
          'https://*.firebaseio.com',
          'https://fcm.googleapis.com',
        ],
        manifestSrc: ["'self'"],
      },
    },
  })
);

app.use(hpp());

// HTTPS enforcement in production (disable with ENFORCE_HTTPS=false until SSL is ready)
if (
  process.env.NODE_ENV === 'production'
  && String(process.env.ENFORCE_HTTPS || 'true').toLowerCase() !== 'false'
) {
  app.use((req, res, next) => {
    if (req.header('x-forwarded-proto') !== 'https') {
      return res.redirect(301, `https://${req.header('host')}${req.url}`);
    }
    next();
  });
}

// Serve public folder for service worker
app.use(express.static(path.join(__dirname, '../public')));

// Uploaded admin images
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use(express.json({ limit: '1mb' }));
app.use(requestLogger);
app.use(collectMetrics);
initializeSecurity(app);
app.use('/api', apiRateLimiter);

const customerHtmlPath = path.join(__dirname, '../customer/index.html');
const customerAppExists = fs.existsSync(customerHtmlPath);
const adminHtmlPath = path.join(__dirname, '../admin/admin.html');
const adminAppExists = fs.existsSync(adminHtmlPath);

const sendAdminPage = (res) => {
  if (adminAppExists) {
    return res.sendFile(adminHtmlPath);
  }

  return res
    .status(200)
    .type('html')
    .send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Meatvo Admin</title>
    <style>
      body { font-family: Arial, sans-serif; background: #f8f8f8; color: #222; margin: 0; padding: 40px 20px; }
      .card { max-width: 640px; margin: 0 auto; background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.08); }
      h1 { margin-top: 0; color: #b71c1c; }
      code { background: #f4f4f4; padding: 2px 6px; border-radius: 6px; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Meatvo admin panel</h1>
      <p>The web admin bundle is not available in this workspace, so <code>/admin</code> cannot serve a static SPA here.</p>
      <p>Use the Flutter mobile app admin dashboard or <code>/api/admin/*</code> APIs for admin operations.</p>
    </div>
  </body>
</html>`);
};

const sendCustomerPage = (res) => {
  if (customerAppExists) {
    return res.sendFile(customerHtmlPath);
  }

  return res
    .status(200)
    .type('html')
    .send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Meatvo Backend</title>
    <style>
      body { font-family: Arial, sans-serif; background: #f8f8f8; color: #222; margin: 0; padding: 40px 20px; }
      .card { max-width: 640px; margin: 0 auto; background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.08); }
      h1 { margin-top: 0; color: #b71c1c; }
      code { background: #f4f4f4; padding: 2px 6px; border-radius: 6px; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Meatvo backend is running</h1>
      <p>The customer web app bundle is not available in this workspace, so <code>/customer</code> cannot serve a static SPA here.</p>
      <p>Use <code>/health</code> for status checks and the mobile app or frontend dev server for customer UI testing.</p>
    </div>
  </body>
</html>`);
};

app.get('/', (req, res) => {
  return ok(res, {
    status: 'ok',
    service: 'meatvo-backend',
    customerAppAvailable: customerAppExists,
    health: '/health',
  }, 'Backend is running');
});

// Health & metrics routes (/, /db, /ready, /live, /comprehensive)
app.use('/health', healthRoutes);
app.use('/metrics', metricsRouter);

// API routes - using modular endpoints
app.use('/api/auth', authIpRateLimiter, authRoutes);
if (String(process.env.NODE_ENV || '').toLowerCase() !== 'production') {
  app.use('/api/debug', debugRoutes);
}
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
app.use('/api/orders/enhanced', enhancedOrdersRoutes);
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

// SPA fallback routes - AFTER API routes (must NOT match /api/admin/*)
app.get('/admin', (req, res) => sendAdminPage(res));

app.get('/customer', (req, res) => {
  return sendCustomerPage(res);
});

const sendDeliveryPage = (res) => {
  const deliveryHtmlPath = path.join(__dirname, '../delivery/delivery.html');
  const mapsKey = String(process.env.GOOGLE_MAPS_API_KEY || '');
  const escapedMapsKey = mapsKey.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  const html = fs.readFileSync(deliveryHtmlPath, 'utf8')
    .replace('<meta name="gmap-key" content="">', `<meta name="gmap-key" content="${escapedMapsKey}">`);

  res.type('html').send(html);
};

app.get('/delivery', (req, res) => {
  sendDeliveryPage(res);
});

// Web admin SPA sub-routes only (not /api/admin/*)
app.get(/^\/admin(?:\/.*)?$/, (req, res) => sendAdminPage(res));

app.get(/\/customer\/.*/, (req, res) => {
  return sendCustomerPage(res);
});

app.get(/\/delivery\/.*/, (req, res) => {
  sendDeliveryPage(res);
});

app.use(errorHandler);

const PORT = Number(process.env.PORT || 8080);
const HOST = process.env.HOST || '0.0.0.0';
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

  server.listen(PORT, HOST, () => {
    console.log(`Server running on ${HOST}:${PORT}`);
    logger.info('server_started', { host: HOST, port: PORT });
  }).on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      logger.error('port_in_use', {
        port: PORT,
        message: `Port ${PORT} is already in use. Kill the process or set a different PORT env var.`,
      });
      process.exit(1);
    } else {
      logger.error('server_error', { message: err?.message, stack: err?.stack });
      process.exit(1);
    }
  });
})();

let shuttingDown = false;

const gracefulShutdown = async (signal) => {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info('graceful_shutdown_started', { signal });

  const forceExitTimer = setTimeout(() => {
    logger.error('graceful_shutdown_timeout');
    process.exit(1);
  }, 15000);
  forceExitTimer.unref();

  try {
    if (socketIo) {
      await new Promise((resolve) => socketIo.close(resolve));
    }
    await new Promise((resolve) => server.close(resolve));
    await pool.end();
    const redisClient = require('./src/db/redis');
    if (typeof redisClient.disconnect === 'function') {
      await redisClient.disconnect();
    }
    logger.info('graceful_shutdown_complete', { signal });
    process.exit(0);
  } catch (err) {
    logger.error('graceful_shutdown_error', { message: err?.message });
    process.exit(1);
  }
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

process.on('uncaughtException', (err) => {
  logger.error('uncaught_exception', { message: err?.message, stack: err?.stack });
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason) => {
  const message = reason instanceof Error ? reason.message : String(reason);
  const stack = reason instanceof Error ? reason.stack : undefined;
  logger.error('unhandled_rejection', { message, stack });
});