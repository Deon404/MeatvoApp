# Meatvo — Technical Requirements Document (TRD)

**Version:** 1.0  
**Date:** June 13, 2026  
**Target Scale:** 100,000 Concurrent Users  
**Classification:** Confidential — CTO Office

---

## Executive Summary

Meatvo is a hyperlocal raw-meat delivery platform architected for rapid scale from MVP (10K users) to enterprise-grade (100K+ users). This document defines the complete technical architecture, implementation standards, and operational requirements to achieve 99.9% uptime, <200ms API response time (P95), and seamless horizontal scalability.

**Technology Stack:**
- **Backend:** Node.js 20 (CommonJS), Express 5
- **Database:** PostgreSQL 15 (ACID-compliant)
- **Cache:** Redis 7 (session, cart, rate limiting)
- **Frontend:** Flutter 3.9+ (iOS/Android), Web SPAs (Admin/Customer/Rider)
- **Infrastructure:** Docker, Ubuntu VPS, Cloudflare CDN
- **Payments:** PhonePe Gateway
- **Real-time:** Socket.io

---

## 1. High-Level Architecture

### 1.1 System Overview

```
┌────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                            │
├────────────────────────────────────────────────────────────────┤
│  Flutter Mobile (iOS/Android)  │  Web SPAs (Admin/Rider)       │
│  • Customer App                │  • Admin Dashboard            │
│  • Rider App                   │  • Analytics & Reports        │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    EDGE / CDN LAYER                            │
├────────────────────────────────────────────────────────────────┤
│  Cloudflare                                                    │
│  • DDoS Protection (L3/L4/L7)  • Rate Limiting (Edge)         │
│  • SSL/TLS Termination         • WAF (OWASP Rules)            │
│  • Static Asset Cache          • Geographic Routing           │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                   REVERSE PROXY / LOAD BALANCER                │
├────────────────────────────────────────────────────────────────┤
│  Nginx 1.24+                                                   │
│  • Load Balancing (Least Conn) • SSL/TLS                      │
│  • HTTP/2 + WebSocket Support  • Compression (Gzip/Brotli)    │
│  • Rate Limiting (Application) • Security Headers             │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                           │
├────────────────────────────────────────────────────────────────┤
│  Node.js 20 + Express 5 (REST API + Socket.io)                │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Core Modules                                            │ │
│  │  • Auth (OTP, JWT, MFA)      • Orders (State Machine)   │ │
│  │  • Products & Catalog        • Payments (PhonePe)       │ │
│  │  • Cart (Redis-backed)       • Delivery (Riders, GPS)   │ │
│  │  • Admin (CRUD, Analytics)   • Notifications (FCM)      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Cross-Cutting Concerns                                  │ │
│  │  • Authentication Guard      • Request Validation        │ │
│  │  • RBAC Authorization        • Error Handling            │ │
│  │  • Rate Limiting             • Audit Logging             │ │
│  │  • Monitoring (Metrics)      • Security (Helmet, HPP)   │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │  PostgreSQL 15       │  │  Redis 7             │          │
│  │  • Master (Write)    │  │  • Session Store     │          │
│  │  • Read Replicas     │  │  • Cache Layer       │          │
│  │  • Connection Pool   │  │  • Pub/Sub (WS)      │          │
│  │  • ACID Transactions │  │  • Rate Limiters     │          │
│  └──────────────────────┘  └──────────────────────┘          │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                   EXTERNAL SERVICES                            │
├────────────────────────────────────────────────────────────────┤
│  • PhonePe (Payments)        • MSG91 (SMS/OTP)                │
│  • Google Maps (Geocoding)   • Firebase FCM (Push)            │
│  • Cloudflare R2 (Storage)   • Sentry (Error Tracking)        │
└────────────────────────────────────────────────────────────────┘
```

### 1.2 Architecture Principles

1. **Stateless Application:** All session state in Redis → horizontal scaling
2. **Modular Monolith:** Clear domain boundaries → microservices-ready
3. **Caching First:** Redis + CDN → 80% cache hit ratio
4. **Event-Driven:** Async jobs (notifications, analytics) → decoupled processing
5. **Security by Design:** Defense in depth → zero-trust architecture
6. **Observability:** Metrics, logs, traces → proactive issue detection

---

## 2. System Components

### 2.1 Application Server

**Technology:** Node.js 20 LTS (CommonJS), Express 5  
**Entry Point:** `backend/index.js`  
**Default Port:** 8080 (internal), 443 (external via Nginx)

**Key Features:**
- RESTful API with `/api/v1` versioning
- Socket.io for real-time communication
- JWT-based authentication (access + refresh tokens)
- Role-based access control (RBAC)
- Comprehensive request validation (Joi)
- Structured logging (Winston)
- Error tracking (Sentry)

**Module Structure:**
```
backend/src/
├── modules/          # Feature modules (controller + routes + validation)
│   ├── auth/         # OTP, JWT, MFA
│   ├── users/        # Profile, preferences
│   ├── products/     # Catalog CRUD
│   ├── categories/   # Hierarchical categories
│   ├── cart/         # Redis-backed cart
│   ├── orders/       # Order state machine
│   ├── payments/     # PhonePe integration
│   ├── delivery/     # Slots, riders, tracking
│   ├── admin/        # Dashboard, analytics
│   └── ...
├── middlewares/      # Auth, RBAC, rate limit, error handling
├── db/               # postgres.js, redis.js, schema.sql
├── security/         # OTP, JWT, payment, socket security
├── services/         # Cross-module services (assignment, tracking)
├── socket/           # Socket.io initialization
├── utils/            # Helpers (response, logger, sms, jwt)
└── routes/           # Health, metrics, debug
```

**Scalability:**
- Horizontal: Docker containers (2-20 instances)
- Vertical: CPU/RAM upgrades (8-32 vCPU, 16-64GB RAM)
- Auto-scaling: CPU > 70% → spawn new container

---

### 2.2 Database Architecture

#### PostgreSQL 15 (Primary Datastore)

**Purpose:** Transactional data (ACID compliance)  
**Connection:** Pool (100 max connections per instance)  
**Backup:** Daily full + 6-hour incremental (30-day retention)

**Key Tables:**
- `users` (customers, riders, admins)
- `addresses` (delivery locations)
- `products` (catalog, inventory)
- `categories` (hierarchical tree)
- `orders` (state machine: PENDING → CONFIRMED → ... → DELIVERED)
- `order_items` (line items)
- `order_status_logs` (audit trail)
- `payments` (PhonePe transactions)
- `delivery_slots` (time windows)
- `rider_locations` (GPS tracking, 30-day retention)
- `coupons` (discount codes)
- `banners` (homepage promotions)

**Optimization Techniques:**
- **Indexes:** Composite indexes on frequent queries (user_id + created_at)
- **Partitioning:** Orders table by month (for >500K orders/month)
- **Read Replicas:** 2 replicas for read-heavy queries (Phase 2)
- **Sharding:** Geographic sharding by city (Phase 3)
- **Materialized Views:** Analytics aggregations (refreshed hourly)

**Performance Targets:**
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Query Response (P95) | <50ms | >200ms |
| Connection Pool Usage | <70% | >90% |
| Cache Hit Ratio | >99% | <95% |
| Slow Queries (>500ms) | 0/hour | >10/hour |

---

#### Redis 7 (Cache & Session Store)

**Purpose:** High-speed cache, session management, rate limiting, pub/sub  
**Connection:** Single instance → Sentinel (HA) → Cluster (sharding)  
**Persistence:** AOF + RDB  
**Max Memory:** 2GB (Phase 1) → 8GB (Phase 2) → 24GB (Phase 3)  
**Eviction Policy:** allkeys-lru

**Data Structures:**
```
# Session Management
session:{userId} → { accessToken, refreshToken, metadata } (TTL: 30 days)

# Cart Storage
cart:{userId} → { items: [{ productId, quantity }], updatedAt } (TTL: 24h)

# OTP Storage
otp:{phone} → { code, attempts, expiresAt } (TTL: 5 min)

# Rate Limiting
ratelimit:{endpoint}:{ip} → { count, resetAt } (TTL: 60s)

# Cache Layer
product:{id} → { ...productData } (TTL: 5 min)
products:list:{filters} → [ ...products ] (TTL: 5 min)
categories:tree → { ...hierarchicalTree } (TTL: 10 min)

# Pub/Sub (Socket.io)
socketio#namespace#room → { event, data }
```

**Scaling Path:**
1. **Phase 1 (10K users):** Single instance (8GB RAM)
2. **Phase 2 (50K users):** Redis Sentinel (1 master + 2 replicas, 24GB total)
3. **Phase 3 (100K users):** Redis Cluster (3 masters + 3 replicas, 48GB total)

---

### 2.3 Frontend Architecture

#### Flutter Mobile App (iOS/Android)

**Framework:** Flutter 3.9+  
**State Management:** Riverpod  
**HTTP Client:** Dio (with interceptors for auth, retry, logging)  
**Real-time:** socket_io_client  
**Storage:** Hive (local DB), flutter_secure_storage (tokens)  
**Maps:** google_maps_flutter, geolocator

**Architecture Pattern:** Clean Architecture (3 layers)
```
Presentation (Screens + Widgets)
      ↓
Business Logic (Providers + Services)
      ↓
Data (API + Repository + Local Storage)
```

**Key Screens:**
- Auth: Splash → Phone OTP → Login
- Home: Banners, categories, featured products
- Catalog: Product listing, search, filters
- Product Detail: Images, description, add to cart
- Cart: Item management, quantity updates
- Checkout: Address selection, slot picker, payment
- Orders: History, live tracking, status updates
- Profile: Account settings, addresses, preferences
- Rider Dashboard: Assigned orders, GPS navigation
- Admin: Dashboard, CRUD operations, analytics

**Performance Optimizations:**
- Shimmer loading states
- Image caching (CachedNetworkImage)
- Lazy loading (pagination)
- Background location updates (rider app)

---

#### Web SPAs (Admin/Customer/Delivery)

**Served By:** Backend Express server (static assets)  
**Path:** `/admin`, `/customer`, `/delivery`  
**Technology:** HTML, CSS, JavaScript (vanilla/framework TBD)  

**Admin Dashboard:**
- Real-time order management
- Product/category CRUD
- User/rider management
- Analytics & reports
- Banner/coupon management
- Settings & configuration

---

### 2.4 Real-Time Architecture (Socket.io)

**Purpose:** Live order tracking, rider location updates  
**Transport:** WebSocket (fallback: long-polling)  
**Authentication:** JWT token in handshake

**Event Flow:**

**Customer Side:**
```javascript
// Join order room
socket.emit('join_order', { orderId });

// Listen for updates
socket.on('order_status_update', { orderId, status, timestamp });
socket.on('order_location_update', { orderId, riderId, lat, lng });
```

**Rider Side:**
```javascript
// Send location updates (every 10s)
socket.emit('rider_location_update', { lat, lng, accuracy, speed });

// Receive order assignments
socket.on('new_order_assigned', { orderId, customer, address });
```

**Scaling Strategy:**
- **Socket.io Redis Adapter:** Cross-server pub/sub
- **Sticky Sessions:** IP hash load balancing
- **Connection Limits:** 10K connections per server → horizontal scaling

---

## 3. Authentication & Authorization

### 3.1 Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  PHONE OTP AUTHENTICATION                   │
└─────────────────────────────────────────────────────────────┘

Step 1: Send OTP
  • User enters phone (+919876543210)
  • Backend validates format (E.164)
  • Rate limit check: 3 OTPs/hour per phone
  • Generate 6-digit OTP (crypto.randomInt)
  • Hash OTP: SHA256(otp + OTP_HASH_SECRET)
  • Store in Redis: { phone, hashedOtp, attempts: 0, expiresAt } (TTL: 5 min)
  • Send via MSG91 SMS gateway

Step 2: Verify OTP
  • User enters OTP
  • Backend retrieves from Redis
  • Verify: constant-time comparison (prevent timing attacks)
  • Max 3 attempts → lock for 15 minutes
  • On success:
    - Create/fetch user record (PostgreSQL)
    - Generate JWT access token (HS256, 15-min expiry)
    - Generate refresh token (HS256, 30-day expiry, stored in DB)
    - Return { accessToken, refreshToken, user }
  • Delete OTP from Redis

Step 3: Subsequent Requests
  • Client sends: Authorization: Bearer <accessToken>
  • Middleware verifies JWT signature & expiry
  • Extract userId & role from token
  • Attach to req.user for downstream handlers

Step 4: Token Refresh
  • Access token expired → Client sends refreshToken
  • Backend validates refresh token (DB lookup)
  • Generate new access token
  • Optional: Rotate refresh token (re-issue new one)
```

**JWT Payload:**
```json
{
  "sub": "uuid-v4",           // User ID
  "role": "CUSTOMER",         // CUSTOMER | RIDER | ADMIN | SUPER_ADMIN
  "iat": 1686580800,          // Issued At
  "exp": 1686581700           // Expiry (15 minutes)
}
```

**Security Measures:**
- **Constant-time comparison:** Prevent timing attacks on OTP verification
- **Rate limiting:** 3 OTP requests per hour per phone, 5 verify attempts per 5 min
- **Account lockout:** 5 failed login attempts → 1-hour lockout
- **JWT secret rotation:** Every 180 days
- **Refresh token invalidation:** On logout, store in Redis blacklist

---

### 3.2 Authorization Model (RBAC)

**Roles:**

| Role | Description | Permissions |
|------|-------------|-------------|
| `CUSTOMER` | End users ordering products | Browse products, manage cart, place orders, view own orders, manage addresses |
| `RIDER` | Delivery personnel | View assigned orders, update order status, send GPS location, upload delivery proof |
| `ADMIN` | Store administrators | Full CRUD on products/categories, manage all orders, assign riders, view analytics |
| `SUPER_ADMIN` | System administrators | All ADMIN permissions + user management, system config, access logs |

**Implementation:**
```javascript
// Middleware: roles.middleware.js
const authorize = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    next();
  };
};

// Usage in routes
router.post('/admin/products', 
  authenticate, 
  authorize('ADMIN', 'SUPER_ADMIN'), 
  productController.create
);

router.get('/orders/:id', 
  authenticate, 
  ownerOrRoleCheck(['ADMIN'], 'userId'), // Customer sees own, Admin sees all
  orderController.getById
);
```

**Row-Level Security:**
- Customers: Can only access own orders, addresses
- Riders: Can only access assigned orders
- Admins: Full access

---

### 3.3 Multi-Factor Authentication (MFA)

**Status:** Optional (enabled for admin accounts)  
**Method:** TOTP (Time-based One-Time Password) using speakeasy  
**Backup Codes:** 10 single-use recovery codes (bcrypt hashed)

**Setup Flow:**
1. Admin enables MFA in settings
2. Backend generates TOTP secret, QR code
3. Admin scans with authenticator app (Google Authenticator)
4. Verify TOTP code → Store encrypted secret in DB
5. Generate backup codes → Display once

**Login Flow (MFA enabled):**
1. Phone OTP verification (primary auth)
2. Prompt for TOTP code
3. Verify TOTP (30-second window, ±1 time step tolerance)
4. Issue JWT tokens

**Encryption:** MFA secrets encrypted with `MFA_ENCRYPTION_KEY` (AES-256-GCM)

---

## 4. Payment Architecture

### 4.1 PhonePe Integration

**Gateway:** PhonePe Payment Gateway (PCI-DSS Level 1)  
**Environment:** Sandbox (dev) | Production  
**Supported Methods:** UPI, Cards, Net Banking, Wallets

**Payment Flow:**

```
┌─────────────────────────────────────────────────────────────┐
│                    PAYMENT WORKFLOW                         │
└─────────────────────────────────────────────────────────────┘

Step 1: Order Creation (POST /api/orders)
  • Customer submits cart, address, delivery slot
  • Backend:
    - Validate inventory
    - Calculate totals (subtotal, tax, delivery fee, discount)
    - Create order (status: PENDING, paymentStatus: PENDING)
    - Create payment record (PhonePe merchantTransactionId)

Step 2: Payment Initiation (POST /api/payments/initiate)
  • Backend calls PhonePe API:
    POST https://api.phonepe.com/apis/hermes/pg/v1/pay
    Body: {
      merchantId, merchantTransactionId,
      merchantUserId, amount, redirectUrl,
      redirectMode: "REDIRECT", callbackUrl
    }
    Headers: { X-VERIFY: base64(sha256(payload + "/pg/v1/pay" + saltKey) + "###" + saltIndex) }
  • PhonePe returns: { success: true, data: { instrumentResponse: { redirectInfo: { url } } } }
  • Return redirect URL to client

Step 3: User Payment
  • Mobile app opens PhonePe URL (WebView / external browser)
  • User completes payment (UPI PIN / card details)
  • PhonePe redirects to redirectUrl with status

Step 4: Payment Verification (Client-side callback)
  • Client receives redirect: meatvo://payment?status=SUCCESS&merchantTransactionId=xxx
  • Client calls: POST /api/payments/verify { merchantTransactionId }
  • Backend calls PhonePe Status API:
    GET https://api.phonepe.com/apis/hermes/pg/v1/status/{merchantId}/{merchantTransactionId}
    Headers: { X-VERIFY: sha256("/pg/v1/status/{merchantId}/{merchantTransactionId}" + saltKey) + "###" + saltIndex }
  • PhonePe returns: { success: true, code: "PAYMENT_SUCCESS", data: { transactionId, amount, state: "COMPLETED" } }
  • Verify checksum, amount match
  • Update order: status → CONFIRMED, paymentStatus → PAID
  • Clear cart from Redis
  • Trigger notifications (email, SMS, push)

Step 5: Webhook (Server-side callback)
  • PhonePe sends POST to callbackUrl: /api/payments/webhook
  • Verify X-VERIFY header (HMAC signature)
  • Process payment status update (idempotent)
  • Update order status if not already updated
```

**Security Measures:**
- **Checksum Verification:** SHA256 HMAC with salt key
- **Amount Validation:** Verify amount matches order total
- **Idempotency:** Webhook handler checks existing payment status
- **IP Whitelisting:** Only accept webhooks from PhonePe IPs
- **Audit Logging:** Log all payment transactions with gateway responses

**COD (Cash on Delivery):**
- Order created with paymentMethod: 'COD', paymentStatus: 'PENDING'
- Payment collected by rider upon delivery
- Rider updates: paymentStatus → 'PAID' (with photo proof)

---

### 4.2 Refund Processing

**Trigger:** Order cancellation (before PICKED_UP status)

**Flow:**
1. Customer cancels order
2. Backend checks: payment status = PAID & cancellation allowed
3. Call PhonePe Refund API:
   ```
   POST /apis/hermes/pg/v1/refund
   Body: { merchantId, originalTransactionId, amount, merchantTransactionId }
   ```
4. PhonePe processes refund (3-7 business days)
5. Update order: status → CANCELLED, paymentStatus → REFUNDED
6. Log refund transaction

---

## 5. Notification Architecture

### 5.1 Multi-Channel Notifications

**Channels:**
1. **Push Notifications (FCM):** Real-time app alerts
2. **SMS (MSG91):** OTP, order updates for critical events
3. **Email:** Order confirmations, receipts (future)
4. **In-App (Socket.io):** Live status updates

**Notification Events:**

| Event | Trigger | Channels | Priority |
|-------|---------|----------|----------|
| OTP Sent | User requests login | SMS | Critical |
| Order Confirmed | Payment success | Push, SMS | High |
| Order Preparing | Admin updates status | Push | Medium |
| Order Out for Delivery | Rider picks up | Push, SMS | High |
| Order Delivered | Rider marks delivered | Push, SMS | High |
| Order Cancelled | Customer/admin cancels | Push, SMS | Medium |
| Payment Failed | PhonePe webhook | Push | High |
| Coupon Expiring | Scheduled job | Push | Low |

**Implementation:**

**Async Job Queue (Bull + Redis):**
```javascript
// Producer (order creation)
await notificationQueue.add('order-confirmation', {
  userId, orderId, type: 'push'
}, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 5000 }
});

// Consumer (worker process)
notificationProcessor.process('order-confirmation', async (job) => {
  const { userId, orderId, type } = job.data;
  
  if (type === 'push') {
    await fcmService.sendOrderUpdate(userId, orderId);
  } else if (type === 'sms') {
    await msg91Service.sendOrderSMS(userId, orderId);
  }
});
```

**Rate Limiting:**
- SMS: 10 per user per day (cost control)
- Push: 50 per user per day (prevent spam)
- Email: 20 per user per day

---

### 5.2 Firebase Cloud Messaging (FCM)

**Setup:**
- Server: FCM Admin SDK (service account JSON)
- Client: flutter_firebase_messaging (device token registration)

**Token Management:**
- Store FCM token in `users.fcm_token` column
- Update on app launch, token refresh
- Remove on logout, app uninstall

**Notification Payload:**
```json
{
  "notification": {
    "title": "Order Confirmed!",
    "body": "Your order #ORD-001 has been confirmed and will be delivered soon."
  },
  "data": {
    "type": "order_update",
    "orderId": "uuid-v4",
    "status": "CONFIRMED",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "token": "<device_fcm_token>"
}
```

**Client Handling:**
```dart
// Foreground
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Show in-app notification
});

// Background / Terminated
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// Tap action
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // Navigate to order detail screen
  Navigator.pushNamed(context, '/orders/${message.data['orderId']}');
});
```

---

## 6. Rider Tracking Architecture

### 6.1 GPS Location Updates

**Frequency:** Every 10 seconds (active delivery), 60 seconds (idle)  
**Accuracy:** <50 meters  
**Protocol:** Socket.io (real-time) + HTTP fallback

**Flow:**

**Rider App:**
```dart
// Background location updates (flutter_background_location)
BackgroundLocation.startLocationService(distanceFilter: 10);

BackgroundLocation.getLocationUpdates((location) {
  socketService.emit('rider_location_update', {
    'latitude': location.latitude,
    'longitude': location.longitude,
    'accuracy': location.accuracy,
    'speed': location.speed,
    'bearing': location.bearing,
    'timestamp': DateTime.now().toIso8601String(),
  });
});
```

**Backend (Socket.io handler):**
```javascript
socket.on('rider_location_update', async (data) => {
  const riderId = socket.user.id;
  
  // Save to PostgreSQL (rider_locations table)
  await db.query(`
    INSERT INTO rider_locations (rider_id, latitude, longitude, accuracy, speed, bearing, timestamp)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
  `, [riderId, data.latitude, data.longitude, data.accuracy, data.speed, data.bearing, data.timestamp]);
  
  // Get active orders for rider
  const orders = await db.query(`
    SELECT id FROM orders WHERE rider_id = $1 AND status IN ('PICKED_UP', 'OUT_FOR_DELIVERY')
  `, [riderId]);
  
  // Broadcast to customers in order rooms
  orders.rows.forEach(order => {
    io.to(`order:${order.id}`).emit('order_location_update', {
      orderId: order.id,
      riderId,
      latitude: data.latitude,
      longitude: data.longitude,
      timestamp: data.timestamp
    });
  });
});
```

**Customer App:**
```dart
// Real-time map updates
socketService.on('order_location_update', (data) {
  setState(() {
    riderLocation = LatLng(data['latitude'], data['longitude']);
    
    // Update map marker, polyline
    _updateMapMarkers();
    _drawRoute(deliveryAddress, riderLocation);
  });
});
```

---

### 6.2 Route Optimization

**Current:** Google Maps Directions API (straight line)  
**Future:** Optimization algorithms (multiple orders per rider)

**Distance Calculation:**
```javascript
// Haversine formula
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}
```

**ETA Calculation:**
```javascript
// Simple model: distance / average speed + buffer
const distance = calculateDistance(rider.lat, rider.lng, order.address.lat, order.address.lng);
const avgSpeed = 25; // km/h (urban traffic)
const buffer = 10; // minutes
const etaMinutes = (distance / avgSpeed) * 60 + buffer;
```

---

### 6.3 Data Retention

**Policy:** Keep location logs for 30 days, then auto-delete  
**Reason:** Privacy compliance, storage optimization  
**Cron Job:**
```bash
# Daily at 3 AM UTC
0 3 * * * psql -d meatvo_db -c "DELETE FROM rider_locations WHERE timestamp < NOW() - INTERVAL '30 days';"
```

---

## 7. Deployment Architecture

### 7.1 Infrastructure Stack

**Hosting:** Ubuntu 22.04 LTS VPS (DigitalOcean / AWS EC2)  
**Region:** Mumbai, India (ap-south-1) — low latency for Indian users  
**Specs (Phase 1):** 8 vCPU, 16GB RAM, 200GB SSD  
**Containerization:** Docker 24.x + Docker Compose  
**Reverse Proxy:** Nginx 1.24+  
**CDN:** Cloudflare (DDoS protection, WAF, edge caching)  
**CI/CD:** GitHub Actions

**Deployment Topology:**

```
VPS: 68.178.XX.XX (Mumbai)
├── Nginx (Port 80, 443)
│   ├── SSL/TLS: Let's Encrypt (auto-renewed)
│   └── Load Balance: Least connections
├── Docker Compose Stack
│   ├── meatvo-api-1 (Port 8080)
│   ├── meatvo-api-2 (Port 8081)
│   ├── meatvo-db (PostgreSQL, Port 5432)
│   ├── meatvo-cache (Redis, Port 6379)
│   ├── prometheus (Metrics, Port 9090)
│   └── grafana (Dashboards, Port 3000)
└── Cron Jobs
    ├── Database backup (2 AM daily)
    ├── Incremental backup (6-hour)
    └── Log rotation (weekly)
```

---

### 7.2 Docker Compose Configuration

**Key Highlights:**
```yaml
services:
  api:
    image: meatvo/backend:latest
    deploy:
      replicas: 2  # Horizontal scaling
      resources:
        limits: { cpus: '2', memory: 4G }
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}

  postgres:
    image: postgres:15-alpine
    command: >
      postgres
      -c max_connections=200
      -c shared_buffers=1GB
      -c effective_cache_size=4GB
    volumes:
      - postgres-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    command: >
      redis-server
      --requirepass ${REDIS_PASSWORD}
      --maxmemory 2gb
      --maxmemory-policy allkeys-lru
      --appendonly yes
```

---

### 7.3 CI/CD Pipeline (GitHub Actions)

**Trigger:** Push to `main` branch  
**Steps:**
1. **Test:** Run Jest unit & integration tests
2. **Security Audit:** `npm audit --audit-level=high`
3. **Build:** Docker image with multi-stage build
4. **Tag:** `meatvo/backend:{commit-sha}` + `latest`
5. **Push:** Docker Hub registry
6. **Deploy:** SSH to VPS → `docker-compose pull && up -d`
7. **Migrate:** Run database migrations
8. **Health Check:** Verify `/health` endpoint returns 200
9. **Notify:** Slack alert (success/failure)

**Rollback:**
```bash
# Quick rollback to previous image
docker-compose down
docker-compose up -d meatvo/backend:<previous-sha>
docker-compose exec api npm run migration:revert
```

**Deployment Frequency:** 2-5 times per week (MVP), 1-2 times per day (mature)

---

## 8. Monitoring & Logging

### 8.1 Metrics Collection (Prometheus + Grafana)

**Prometheus Exporters:**
- Node.js app: `prom-client` library
- PostgreSQL: `postgres_exporter`
- Redis: `redis_exporter`
- System: `node_exporter`

**Key Metrics:**

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `http_requests_total` | Total HTTP requests (by method, route, status) | - |
| `http_request_duration_seconds` | Request latency histogram | P95 > 500ms |
| `http_requests_errors_total` | Error count | Rate > 5% for 5 min |
| `db_connections_active` | Active PostgreSQL connections | > 90/100 |
| `db_query_duration_seconds` | Query execution time | P95 > 200ms |
| `redis_memory_used_bytes` | Redis memory usage | > 1.8GB (90%) |
| `redis_connected_clients` | Active Redis connections | > 9000 (90%) |
| `active_orders_total` | Orders by status | - |
| `websocket_connections_total` | Active WebSocket connections | - |
| `nodejs_heap_size_used_bytes` | Node.js memory usage | > 3.6GB (90% of 4GB limit) |

**Grafana Dashboards:**
1. **API Performance:** RPS, latency (P50/P95/P99), error rate
2. **Database Health:** Query performance, connection pool, cache hit ratio
3. **Business Metrics:** Orders/hour, revenue, top products
4. **System Resources:** CPU, memory, disk I/O, network

---

### 8.2 Logging Strategy (Winston)

**Log Levels:** ERROR, WARN, INFO, DEBUG  
**Format:** JSON (structured logging)  
**Transports:**
- **Console:** Development only
- **File:** Production (rotated daily, 90-day retention)
- **Future:** Elasticsearch (ELK stack for centralized logging)

**Log Structure:**
```json
{
  "timestamp": "2026-06-13T14:30:00.123Z",
  "level": "info",
  "message": "Order created successfully",
  "service": "orders",
  "userId": "uuid-v4",
  "orderId": "uuid-order",
  "method": "POST",
  "path": "/api/orders",
  "statusCode": 201,
  "duration": 45,
  "ip": "103.45.67.89",
  "userAgent": "MeatvoApp/1.0.0 (Android 12)",
  "requestId": "req_7f3b9c8a"
}
```

**Critical Events Logged:**
- Authentication (login, logout, OTP sent/verified)
- Authorization failures (403 errors)
- Order lifecycle (created, confirmed, cancelled, delivered)
- Payment transactions (initiated, verified, failed, refunded)
- Admin actions (product CRUD, order updates, user management)
- Errors (500, uncaught exceptions, API failures)

---

### 8.3 Error Tracking (Sentry)

**Integration:** `@sentry/node`  
**Environment:** Production only (DSN in env variable)  
**Features:**
- Automatic error capture (uncaught exceptions, unhandled rejections)
- Request context (user, URL, headers)
- Breadcrumbs (last 100 user actions before error)
- Release tracking (Git commit SHA)
- Performance monitoring (transaction traces)

**Alert Rules:**
- New error type → Slack notification
- Error frequency > 100/hour → PagerDuty critical alert
- Payment errors → Immediate Slack + email

---

### 8.4 Alerting Rules

**Critical (PagerDuty):**
- API error rate > 5% for 5 minutes
- Database connection pool > 90% for 2 minutes
- Disk usage > 90%
- Health check fails 3 consecutive times
- Payment gateway errors > 5 in 1 minute

**High (Slack):**
- API P95 latency > 500ms for 10 minutes
- Order processing delay > 2 minutes
- Redis memory > 80%
- WebSocket connection drops > 50/minute

**Medium (Email):**
- Slow queries > 1 second detected
- Backup failure
- SSL certificate expiry < 7 days
- Unusual traffic spike (>200% of average)

---

## 9. Backup & Disaster Recovery

### 9.1 Backup Strategy

**PostgreSQL Backups:**
```bash
# Full backup (daily at 2 AM UTC)
pg_dump -U meatvo_user -d meatvo_db | gzip > /backups/meatvo_$(date +%Y%m%d_%H%M%S).sql.gz

# Encrypt backup
openssl enc -aes-256-cbc -salt -in backup.sql.gz -out backup.sql.gz.enc -pass env:BACKUP_PASSWORD

# Upload to Cloudflare R2 (S3-compatible)
aws s3 cp backup.sql.gz.enc s3://meatvo-backups/database/ --endpoint-url https://account-id.r2.cloudflarestorage.com

# Incremental backup (every 6 hours): WAL archiving
# Configured in postgresql.conf:
# wal_level = replica
# archive_mode = on
# archive_command = 'test ! -f /backups/wal/%f && cp %p /backups/wal/%f'
```

**Retention Policy:**
- Daily backups: 30 days
- WAL archives: 7 days
- Monthly backups: 12 months (first backup of each month)

**Redis Persistence:**
- AOF (Append-Only File): `appendonly yes`
- RDB snapshot: Every 300 seconds if 10+ keys changed
- Backup both AOF + RDB files daily

**Code & Config:**
- Git repository (GitHub, private)
- Secrets: AWS Secrets Manager + encrypted local backup

**Recovery Targets:**
- **RTO (Recovery Time Objective):** 2 hours
- **RPO (Recovery Point Objective):** 1 hour (6-hour incremental backups)

---

### 9.2 Disaster Recovery Procedures

**Scenario 1: Database Corruption**
```bash
# 1. Stop application
docker-compose stop api

# 2. Download latest backup from R2
aws s3 cp s3://meatvo-backups/database/latest.sql.gz.enc /tmp/ --endpoint-url ...

# 3. Decrypt and restore
openssl enc -d -aes-256-cbc -in /tmp/latest.sql.gz.enc -out /tmp/restore.sql.gz -pass env:BACKUP_PASSWORD
gunzip < /tmp/restore.sql.gz | docker exec -i meatvo-db psql -U meatvo_user -d meatvo_db

# 4. Apply WAL logs (point-in-time recovery)
# Configured in recovery.conf

# 5. Restart application
docker-compose start api

# 6. Verify health
curl https://api.meatvo.com/health
```

**Scenario 2: Complete Server Failure**
1. Provision new VPS (Ubuntu 22.04, same region)
2. Install Docker + Docker Compose
3. Clone repository: `git clone https://github.com/meatvo/backend`
4. Restore `.env` from AWS Secrets Manager
5. Download database backup from R2
6. Start services: `docker-compose up -d`
7. Restore database (as above)
8. Update DNS (Cloudflare) to point to new server IP
9. Verify health + smoke tests

**Failover Strategy:**
- **Primary VPS:** Mumbai (active)
- **Secondary VPS:** Bangalore (cold standby, manual failover)
- **DNS TTL:** 300 seconds (5 minutes) for quick failover

---

## 10. Scaling Strategy (10K → 100K Users)

### 10.1 Scaling Phases

**Phase 1: MVP (0-10K users) ✅ Current**
- Single VPS (8 vCPU, 16GB RAM, 200GB SSD)
- Docker Compose (2 API containers, 1 DB, 1 Redis)
- Nginx load balancing (round-robin)
- Capacity: 5,000 req/min, 5,000 orders/month

**Infrastructure Cost:** $410/month (VPS $120 + CDN $20 + Storage $15 + Domain $1 + SMS $50 + Maps $200 + GitHub $4)

---

**Phase 2: Growth (10K-50K users)**
- **Horizontal Scaling:**
  - 3 VPS servers (application tier)
  - Dedicated database VPS (8 vCPU, 16GB RAM)
  - Dedicated Redis VPS (4 vCPU, 8GB RAM)
  - HAProxy / AWS ALB load balancer
- **Database Optimization:**
  - PostgreSQL read replicas (2 replicas)
  - Redis Sentinel (1 master + 2 replicas for HA)
- **Async Processing:**
  - Bull queue workers (3 worker processes)
- **Monitoring:**
  - Prometheus + Grafana (alerting)
  - ELK stack for centralized logging

**Capacity:** 25,000 req/min, 50,000 orders/month  
**Infrastructure Cost:** $2,500/month

---

**Phase 3: Scale (50K-100K users)**
- **Kubernetes Migration:**
  - EKS / GKE cluster (10+ nodes)
  - Auto-scaling (HPA based on CPU/memory)
  - Ingress controller (Nginx Ingress)
- **Database Sharding:**
  - Geographic sharding by city (Mumbai, Bangalore, Delhi shards)
  - Application-level routing
- **Redis Cluster:**
  - 6 nodes (3 masters + 3 replicas)
  - Hash slot-based sharding
- **Multi-Region Deployment:**
  - Mumbai (primary), Bangalore (replica)
  - GeoDNS routing (Cloudflare)
- **Advanced Caching:**
  - Varnish cache (edge caching)
  - CDN edge compute (Cloudflare Workers for personalization)
- **Search & Analytics:**
  - Elasticsearch (product search, analytics)

**Capacity:** 50,000+ req/min, 500,000 orders/month  
**Infrastructure Cost:** $5,000-$8,000/month

---

### 10.2 Auto-Scaling Rules

**Kubernetes HPA (Horizontal Pod Autoscaler):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: meatvo-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: meatvo-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50  # Scale up by 50% of current pods
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 25  # Scale down by 25% of current pods
        periodSeconds: 60
```

**Database Auto-Scaling:**
- Vertical: AWS RDS automated scaling (storage)
- Horizontal: Add read replicas when master CPU > 70%

---

### 10.3 Performance Targets (100K Users)

| Metric | Target | Current (10K) |
|--------|--------|---------------|
| Concurrent Users | 100,000 | 10,000 |
| Requests/Second | 50,000 | 5,000 |
| API Response Time (P95) | <200ms | 180ms |
| WebSocket Connections | 50,000 | 5,000 |
| Orders/Day | 15,000 | 150 |
| Database Queries/Second | 50,000 | 5,000 |
| Cache Hit Ratio | >95% | 80% |
| Uptime SLA | 99.9% | 99.95% |

---

## 11. Security Model

### 11.1 Defense in Depth

**Layer 1: Edge (Cloudflare)**
- DDoS protection (L3/L4/L7)
- WAF (OWASP Top 10 rules)
- Rate limiting (100 req/min per IP)
- Bot detection & mitigation

**Layer 2: Network (Nginx)**
- SSL/TLS 1.3 (Let's Encrypt)
- Rate limiting (20 req/min for auth, 100 req/min for API)
- IP whitelisting (admin endpoints)
- Request size limits (10MB max)

**Layer 3: Application (Express)**
- Helmet.js (security headers: CSP, HSTS, X-Frame-Options)
- HPP (HTTP Parameter Pollution protection)
- Input validation (Joi schemas)
- Output sanitization (prevent XSS)
- CORS (whitelist origins)

**Layer 4: Authentication & Authorization**
- JWT-based auth (HS256, 15-min access token)
- OTP-based login (6-digit, 5-min expiry)
- RBAC (Customer, Rider, Admin, Super Admin)
- Account lockout (5 failed attempts → 1-hour lock)

**Layer 5: Data**
- PostgreSQL: TLS connections, parameterized queries, RLS (Row-Level Security)
- Redis: Password authentication, TLS, dangerous commands disabled
- Encryption at rest: LUKS disk encryption
- Encryption in transit: TLS 1.3 for all services

**Layer 6: External Services**
- PhonePe: Checksum verification, IP whitelisting
- MSG91: API key in env variable, rate limiting
- Firebase: Service account with least privilege

---

### 11.2 OWASP Top 10 Mitigation

| Vulnerability | Mitigation |
|---------------|------------|
| **A01: Broken Access Control** | RBAC middleware, row-level checks (customer sees own orders), JWT verification |
| **A02: Cryptographic Failures** | TLS 1.3, bcrypt (password hashing), JWT secrets (256-bit), AES-256 (sensitive data) |
| **A03: Injection** | Parameterized queries (`$1, $2`), Joi validation, no `eval()` or `exec()` |
| **A04: Insecure Design** | Threat modeling, security reviews, principle of least privilege |
| **A05: Security Misconfiguration** | Helmet.js, CSP, HSTS, disable `x-powered-by`, secure defaults |
| **A06: Vulnerable Components** | `npm audit`, Dependabot, Snyk, weekly dependency updates |
| **A07: Authentication Failures** | OTP + JWT, account lockout, constant-time comparison, MFA for admins |
| **A08: Software & Data Integrity** | Code signing (Docker images), checksum verification (PhonePe), audit logs |
| **A09: Security Logging Failures** | Winston structured logs, Sentry error tracking, audit trail (all admin actions) |
| **A10: SSRF** | No user-controlled URLs in server-side requests, URL validation, whitelist allowed domains |

---

### 11.3 Compliance

**PCI-DSS (Payment Card Industry Data Security Standard):**
- Outsourced to PhonePe (PCI-DSS Level 1 certified)
- Never store card numbers, CVV, or expiry dates
- Use tokenization for recurring payments (future)
- TLS for all payment communication

**DPDP Act 2023 (India Data Protection):**
- Data localization: User data stored in India (Mumbai region)
- Consent management: Explicit opt-in for marketing
- Right to access: API endpoint for data export (JSON)
- Right to erasure: Account deletion with data anonymization
- Data retention: 2 years for inactive users, then soft delete

**GDPR-Ready (Future International Expansion):**
- Privacy by design
- Data minimization
- Right to portability
- Breach notification (72 hours)

---

## 12. API Design Standards

### 12.1 RESTful Principles

**URL Structure:**
```
https://api.meatvo.com/api/v1/{resource}
```

**HTTP Methods:**
- `GET` → Retrieve resource(s)
- `POST` → Create new resource
- `PATCH` → Partial update
- `PUT` → Full replacement (rarely used)
- `DELETE` → Remove resource

**Resource Naming:**
- Use plural nouns: `/products`, `/orders`, `/categories`
- Hierarchical: `/orders/:id/items`, `/users/:id/addresses`
- Actions as sub-resources: `/orders/:id/cancel`, `/payments/verify`

**Versioning:**
- URL path: `/api/v1/products` (current)
- Future: `/api/v2/products` when breaking changes needed
- Maintain v1 for 12 months after v2 release

---

### 12.2 Request/Response Format

**Request:**
```json
POST /api/v1/orders
Content-Type: application/json
Authorization: Bearer <token>

{
  "addressId": "uuid-v4",
  "deliverySlotId": "uuid-slot",
  "paymentMethod": "ONLINE",
  "couponCode": "FIRST50",
  "notes": "Ring bell twice"
}
```

**Success Response:**
```json
HTTP/1.1 201 Created
Content-Type: application/json

{
  "success": true,
  "data": {
    "order": { ... },
    "payment": { ... }
  },
  "message": "Order created successfully",
  "timestamp": "2026-06-13T14:30:00Z"
}
```

**Error Response:**
```json
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid address",
    "details": [
      {
        "field": "addressId",
        "constraint": "isUUID",
        "message": "addressId must be a UUID"
      }
    ]
  },
  "timestamp": "2026-06-13T14:30:00Z",
  "requestId": "req_7f3b9c8a"
}
```

---

### 12.3 Pagination

**Query Parameters:**
- `page` (default: 1)
- `limit` (default: 20, max: 100)
- `sortBy` (default: `createdAt`)
- `sortOrder` (`asc` | `desc`, default: `desc`)

**Response:**
```json
{
  "success": true,
  "data": {
    "items": [ ... ],
    "meta": {
      "totalItems": 150,
      "itemCount": 20,
      "itemsPerPage": 20,
      "totalPages": 8,
      "currentPage": 1,
      "hasNextPage": true,
      "hasPreviousPage": false
    }
  }
}
```

---

### 12.4 Rate Limiting

**Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1686580800
```

**429 Response:**
```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please try again in 45 seconds.",
    "retryAfter": 45
  }
}
```

**Rate Limits:**
- OTP Send: 3 requests/hour per phone
- OTP Verify: 5 requests/5 minutes
- Auth endpoints: 20 requests/15 minutes
- API (GET): 100 requests/minute
- API (POST/PATCH/DELETE): 50 requests/minute
- Admin: 200 requests/minute

---

## 13. Coding Standards

### 13.1 Backend (Node.js)

**Module Pattern:**
```
backend/src/modules/{feature}/
├── {feature}.routes.js        # Express routes
├── {feature}.controller.js    # Request handlers
├── {feature}.validation.js    # Joi/Zod schemas
└── {feature}.service.js       # Business logic (optional)
```

**Code Style:**
- ESLint (Airbnb config)
- Prettier (auto-formatting)
- Naming: camelCase (variables, functions), PascalCase (classes)
- File naming: kebab-case (`auth.controller.js`)

**Best Practices:**
```javascript
// ✅ GOOD: Parameterized queries
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

// ILLUSTRATIVE ONLY — use parameterized queries in production code.

// ❌ BAD: String concatenation (SQL injection risk)
const user = await db.query(`SELECT * FROM users WHERE id = '${userId}'`);

// ✅ GOOD: Async error handling
try {
  const order = await orderService.create(orderDto);
  return res.ok(order);
} catch (error) {
  logger.error('Order creation failed', { error, userId });
  return res.fail('Order creation failed');
}

// ✅ GOOD: Input validation
const schema = Joi.object({
  phone: Joi.string().pattern(/^\+91[6-9]\d{9}$/).required(),
  otp: Joi.string().length(6).pattern(/^\d+$/).required(),
});

// ✅ GOOD: Structured logging
logger.info('Order created', { orderId, userId, amount: order.totalAmount });

// ❌ BAD: Console.log
console.log('Order created:', orderId);
```

**Security:**
- Never commit `.env` files
- Use `process.env` for secrets
- Sanitize user input before DB operations
- Use `helmet`, `hpp`, `cors` middleware
- Constant-time comparison for sensitive strings

---

### 13.2 Frontend (Flutter)

**Folder Structure:**
```
frontend/lib/
├── main.dart                  # App entry point
├── config/                    # Environment config
├── core/
│   ├── constants/             # AppColors, AppTextStyles, AppSpacing
│   └── widgets/               # Reusable UI components
├── features/                  # Feature-scoped providers
├── screens/                   # Full-page UI
├── services/                  # API + domain services
├── providers/                 # Riverpod providers
├── models/                    # Data models
├── widgets/                   # Shared UI components
└── utils/                     # Helper functions
```

**Code Style:**
- Dart Analysis (flutter_lints)
- Naming: camelCase (variables, functions), PascalCase (classes, widgets)
- File naming: snake_case (`order_detail_screen.dart`)

**Best Practices:**
```dart
// ✅ GOOD: Use design tokens
Container(
  padding: EdgeInsets.all(AppSpacing.md),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
  ),
  child: Text('Hello', style: AppTextStyles.bodyMedium),
)

// ❌ BAD: Hardcoded values
Container(
  padding: EdgeInsets.all(16),
  color: Color(0xFF1C1C1E),
  child: Text('Hello', style: TextStyle(fontSize: 14)),
)

// ✅ GOOD: API calls via services
final order = await ref.read(orderServiceProvider).getOrderById(orderId);

// ❌ BAD: Direct API calls in widgets
final response = await Dio().get('$baseUrl/orders/$orderId');

// ✅ GOOD: Loading/error states
AsyncValue.when(
  data: (order) => OrderDetailView(order: order),
  loading: () => ShimmerLoader(),
  error: (error, stack) => ErrorWidget(message: error.toString()),
)

// ✅ GOOD: Secure storage for tokens
await secureStorage.write(key: 'accessToken', value: token);

// ❌ BAD: SharedPreferences for sensitive data
await prefs.setString('accessToken', token);
```

---

### 13.3 Database

**Schema Naming:**
- Tables: plural, snake_case (`users`, `order_items`)
- Columns: singular, snake_case (`user_id`, `created_at`)
- Primary keys: `id` (UUID v4)
- Foreign keys: `{table}_id` (e.g., `user_id`)
- Timestamps: `created_at`, `updated_at`, `deleted_at`

**Indexes:**
- Name format: `idx_{table}_{column(s)}`
- Example: `idx_orders_user_id`, `idx_orders_status_created_at`

**Migrations:**
- Tool: Raw SQL files (versioned: `001_initial_schema.sql`)
- Never modify existing migrations (create new ones)
- Always include rollback logic

**Queries:**
```sql
-- ✅ GOOD: Use indexes
SELECT * FROM orders WHERE user_id = $1 AND status = $2 ORDER BY created_at DESC;
-- Index: idx_orders_user_id_status_created_at

-- ❌ BAD: Full table scan
SELECT * FROM orders WHERE LOWER(status) = 'pending';

-- ✅ GOOD: Pagination
SELECT * FROM products WHERE category_id = $1 ORDER BY created_at DESC LIMIT 20 OFFSET 0;

-- ✅ GOOD: JOIN for N+1 prevention
SELECT o.*, oi.* FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.user_id = $1;
```

---

## 14. Key Technical Decisions

### 14.1 Node.js (not Python/Java)

**Rationale:**
- Non-blocking I/O → High concurrency (10K+ connections per server)
- JavaScript ecosystem → Faster development (npm packages)
- Socket.io native support → Real-time tracking
- Lower memory footprint → Cost-effective scaling

**Trade-offs:**
- Single-threaded (mitigated by clustering, Docker replicas)
- Callback hell (mitigated by async/await)

---

### 14.2 PostgreSQL (not MongoDB/MySQL)

**Rationale:**
- ACID transactions → Critical for orders & payments
- Relational model → Strong data consistency (foreign keys)
- Advanced features → JSONB, full-text search, partitioning
- Proven scalability → Read replicas, sharding

**Trade-offs:**
- Vertical scaling limits (mitigated by read replicas, sharding)

---

### 14.3 Redis (not Memcached)

**Rationale:**
- Richer data structures (lists, sets, sorted sets, pub/sub)
- Persistence (AOF + RDB) → Survive restarts
- Socket.io adapter support → Multi-server WebSocket
- Lua scripting → Atomic complex operations

**Trade-offs:**
- Single-threaded (mitigated by clustering)

---

### 14.4 Flutter (not React Native)

**Rationale:**
- True native performance → 60fps animations
- Single codebase (iOS + Android) → Faster development
- Rich UI library (Material + Cupertino) → Beautiful UX
- Strong type safety (Dart) → Fewer runtime errors

**Trade-offs:**
- Larger APK size (mitigated by split APKs)
- Smaller ecosystem vs React Native (but growing rapidly)

---

### 14.5 Monolith (not Microservices)

**Rationale:**
- Simpler deployment → Single Docker image
- Faster development → No inter-service communication
- Easier debugging → Single codebase
- Lower infrastructure cost → Fewer servers

**When to Migrate to Microservices:**
- Team size > 20 developers
- Services have independent scaling needs (e.g., payment gateway)
- Need for polyglot stack (e.g., Python for ML)

**Migration Path:** Extract high-traffic modules (Orders, Delivery, Notifications) into separate services

---

## 15. Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Database becomes bottleneck** | High | Medium | Read replicas, query optimization, Redis caching, sharding |
| **Payment gateway downtime** | Critical | Low | Circuit breaker, retry logic, fallback to COD, status page |
| **DDoS attack** | High | Medium | Cloudflare protection (automatic), rate limiting, IP blacklisting |
| **Data breach** | Critical | Low | Encryption (at rest + in transit), access controls, security audits, penetration testing |
| **OTP SMS delivery failure** | Medium | Medium | Fallback SMS provider, email OTP (future), retry logic |
| **Server crash** | High | Low | Health checks, auto-restart (Docker), standby VPS, backups |
| **Rapid user growth** | Medium | High | Auto-scaling (Kubernetes), load testing, capacity planning |
| **Regulatory changes (DPDP)** | Medium | Medium | Legal review, data retention policies, compliance audits |
| **Third-party API deprecation** | Medium | Low | Abstract external services (adapter pattern), monitor changelogs |

---

## 16. Success Metrics

### 16.1 Technical KPIs

| Metric | Target | Current | Trend |
|--------|--------|---------|-------|
| API Response Time (P95) | <200ms | 180ms | ✅ On track |
| Uptime SLA | 99.9% | 99.95% | ✅ Exceeding |
| Error Rate | <0.5% | 0.2% | ✅ Healthy |
| Cache Hit Ratio | >90% | 80% | ⚠️ Needs improvement |
| Database Query Time (P95) | <50ms | 45ms | ✅ Healthy |
| Payment Success Rate | >97% | 98.5% | ✅ Exceeding |
| WebSocket Connection Success | >99% | 99.7% | ✅ Healthy |
| Mean Time to Recovery (MTTR) | <1 hour | 45 min | ✅ Healthy |

### 16.2 Business KPIs (Tech-Enabled)

| Metric | Target | Current | Impact |
|--------|--------|---------|--------|
| Order Processing Time | <30s | 25s | Fast checkout → Higher conversion |
| Delivery ETA Accuracy | >90% | 85% | Accurate tracking → Customer trust |
| Cart Abandonment Rate | <40% | 52% | Optimize checkout flow |
| App Crash Rate | <0.1% | 0.05% | Stable app → Better retention |
| Real-time Tracking Adoption | >80% | 75% | Socket.io reliability |

---

## 17. Roadmap

### Q3 2026 (Months 7-9)
- [ ] Horizontal scaling (3 VPS servers)
- [ ] PostgreSQL read replicas (2)
- [ ] Redis Sentinel (HA)
- [ ] Elasticsearch (product search)
- [ ] ELK stack (centralized logging)
- [ ] Load testing (k6, 50K concurrent users)

### Q4 2026 (Months 10-12)
- [ ] Kubernetes migration (EKS/GKE)
- [ ] Multi-region deployment (Mumbai + Bangalore)
- [ ] Database sharding (geographic)
- [ ] Advanced fraud detection (ML)
- [ ] Email notifications
- [ ] Loyalty program

### Q1 2027 (Months 13-15)
- [ ] Microservices extraction (Orders, Delivery, Notifications)
- [ ] GraphQL API (for flexible client queries)
- [ ] Redis Cluster (sharding)
- [ ] Machine learning (demand forecasting, dynamic pricing)
- [ ] WhatsApp notifications
- [ ] Subscription model

---

## 18. Appendices

### A. Environment Variables

**Critical Variables:**
```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/meatvo_db
REDIS_URL=redis://:password@localhost:6379

# Authentication
JWT_ACCESS_SECRET=<256-bit-random-key>
JWT_REFRESH_SECRET=<256-bit-random-key>
OTP_HASH_SECRET=<256-bit-random-key>

# Payment
PHONEPE_MERCHANT_ID=<merchant-id>
PHONEPE_SALT_KEY=<salt-key>
PHONEPE_SALT_INDEX=<salt-index>

# SMS
MSG91_AUTH_KEY=<api-key>
MSG91_TEMPLATE_ID=<template-id>

# Maps
GOOGLE_MAPS_API_KEY=<api-key>

# Monitoring
SENTRY_DSN=<sentry-dsn>
```

**See:** `shared/env-manifest.json` for complete list

---

### B. API Endpoints Summary

**Authentication:**
- `POST /api/v1/auth/send-otp`
- `POST /api/v1/auth/verify-otp`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

**Products:**
- `GET /api/v1/products`
- `GET /api/v1/products/:id`
- `GET /api/v1/products/search?q=chicken`
- `GET /api/v1/categories`

**Cart:**
- `GET /api/v1/cart`
- `POST /api/v1/cart/items`
- `PATCH /api/v1/cart/items/:productId`
- `DELETE /api/v1/cart/items/:productId`

**Orders:**
- `POST /api/v1/orders`
- `GET /api/v1/orders`
- `GET /api/v1/orders/:id`
- `POST /api/v1/orders/:id/cancel`

**Payments:**
- `POST /api/v1/payments/initiate`
- `POST /api/v1/payments/verify`
- `POST /api/v1/payments/webhook` (PhonePe)

**Delivery:**
- `GET /api/v1/delivery/slots`
- `POST /api/v1/delivery/check-availability`
- `GET /api/v1/delivery/rider/orders` (Rider)
- `POST /api/v1/delivery/rider/location` (Rider)

**Admin:**
- `GET /api/v1/admin/dashboard`
- `POST /api/v1/admin/products`
- `PATCH /api/v1/admin/products/:id`
- `DELETE /api/v1/admin/products/:id`

**See:** [API Documentation](./API_DOCUMENTATION.md) for full specs

---

### C. Database Schema

**See:** [Database Design](./DATABASE_DESIGN.md) for complete ERD, table specs, indexes

---

### D. Technology Versions

| Technology | Version | Release Date | EOL Date |
|------------|---------|--------------|----------|
| Node.js | 20 LTS | 2023-10-24 | 2026-04-30 |
| Express | 5.x | 2024 | Active |
| PostgreSQL | 15.x | 2022-10-13 | 2027-11-11 |
| Redis | 7.x | 2022-04-27 | Active |
| Flutter | 3.9+ | 2023-05-10 | Active |
| Docker | 24.x | 2023-07-24 | Active |
| Ubuntu | 22.04 LTS | 2022-04-21 | 2027-04 |

---

### E. Glossary

- **ACID:** Atomicity, Consistency, Isolation, Durability
- **AOF:** Append-Only File (Redis persistence)
- **CDN:** Content Delivery Network
- **CORS:** Cross-Origin Resource Sharing
- **COD:** Cash on Delivery
- **CSP:** Content Security Policy
- **DDoS:** Distributed Denial of Service
- **ETA:** Estimated Time of Arrival
- **FCM:** Firebase Cloud Messaging
- **HA:** High Availability
- **HMAC:** Hash-based Message Authentication Code
- **HPA:** Horizontal Pod Autoscaler (Kubernetes)
- **HSTS:** HTTP Strict Transport Security
- **JWT:** JSON Web Token
- **MAU:** Monthly Active Users
- **MFA:** Multi-Factor Authentication
- **MTTR:** Mean Time to Recovery
- **OTP:** One-Time Password
- **P95:** 95th percentile
- **PCI-DSS:** Payment Card Industry Data Security Standard
- **RBAC:** Role-Based Access Control
- **RLS:** Row-Level Security (PostgreSQL)
- **RPO:** Recovery Point Objective
- **RPS:** Requests per Second
- **RTO:** Recovery Time Objective
- **SLA:** Service Level Agreement
- **TLS:** Transport Layer Security
- **TOTP:** Time-based One-Time Password
- **TTL:** Time to Live
- **VPS:** Virtual Private Server
- **WAF:** Web Application Firewall
- **WAL:** Write-Ahead Logging (PostgreSQL)

---

## Document Control

**Approvals:**
- CTO: ________________________ Date: __________
- Lead Backend Engineer: ________________________ Date: __________
- DevOps Lead: ________________________ Date: __________

**Revision History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-13 | CTO Office | Initial release |

**Related Documents:**
- [Product Requirements Document](./PRODUCT_REQUIREMENTS_DOCUMENT.md)
- [System Architecture](./SYSTEM_ARCHITECTURE.md)
- [Database Design](./DATABASE_DESIGN.md)
- [Security Architecture](./SECURITY_ARCHITECTURE.md)
- [API Documentation](./API_DOCUMENTATION.md)
- [Infrastructure](./INFRASTRUCTURE.md)
- [Scalability Strategy](./SCALABILITY_STRATEGY.md)

---

*Document Classification: Confidential — Technical Requirements*  
*Target Audience: CTO, Engineering Leads, DevOps Team*  
*Last Updated: June 13, 2026*  
*Next Review: September 2026*
