# Meatvo — System Architecture

**Version:** 1.0  
**Date:** June 12, 2026  
**Architecture Owner:** CTO Office

---

## 1. Architecture Overview

### 1.1 Design Principles
1. **Scalability First:** Horizontal scaling for 100K+ concurrent users
2. **High Availability:** 99.9% uptime SLA with automated failover
3. **Security by Design:** Zero-trust architecture, defense in depth
4. **Performance:** <200ms API response time (P95), <3s page load
5. **Cost Efficiency:** Cloud-native, pay-as-you-grow infrastructure
6. **Observability:** Full-stack monitoring, distributed tracing, alerting

### 1.2 Architectural Style
**Modular Monolith with Microservices-Ready Design**
- Single NestJS application with clear domain boundaries
- Future-proof for microservices decomposition as scale demands
- Event-driven communication between modules

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  Flutter Mobile App (iOS/Android)  │  Web Dashboard (Admin)     │
│  • Customer App                    │  • Admin Panel             │
│  • Rider App                       │  • Analytics Dashboard     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CDN / EDGE LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│  Cloudflare                                                     │
│  • DDoS Protection          • SSL/TLS Termination              │
│  • Edge Caching             • Rate Limiting                    │
│  • WAF (Web Application Firewall)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    REVERSE PROXY / LOAD BALANCER                │
├─────────────────────────────────────────────────────────────────┤
│  Nginx                                                          │
│  • SSL/TLS                  • HTTP/2, WebSocket Support        │
│  • Load Balancing           • Request Routing                  │
│  • Gzip Compression         • Security Headers                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│  NestJS Backend (Node.js)                                       │
│  ┌──────────────────┐  ┌──────────────────┐                   │
│  │  REST API        │  │  WebSocket       │                   │
│  │  (Express)       │  │  (Socket.io)     │                   │
│  └──────────────────┘  └──────────────────┘                   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │              CORE MODULES                              │   │
│  ├────────────────────────────────────────────────────────┤   │
│  │ • Auth          • Products      • Orders              │   │
│  │ • Users         • Categories    • Cart                │   │
│  │ • Payments      • Delivery      • Notifications       │   │
│  │ • Admin         • Analytics     • Inventory           │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │            CROSS-CUTTING CONCERNS                      │   │
│  ├────────────────────────────────────────────────────────┤   │
│  │ • Authentication    • Logging         • Validation     │   │
│  │ • Authorization     • Error Handling  • Caching        │   │
│  │ • Rate Limiting     • Monitoring      • Audit Trail    │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                   │
│  │  PostgreSQL      │  │  Redis           │                   │
│  │  • Transactional │  │  • Session Store │                   │
│  │  • Relational    │  │  • Cache Layer   │                   │
│  │  • ACID          │  │  • Pub/Sub       │                   │
│  └──────────────────┘  └──────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SERVICES                            │
├─────────────────────────────────────────────────────────────────┤
│  • Razorpay (Payments)        • Firebase FCM (Push)            │
│  • Google Maps API            • Cloudflare R2 (Storage)        │
│  • SMS Gateway (OTP)          • Email Service (Transactional)  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Component Architecture

### 3.1 Frontend Architecture (Flutter)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│  Screens (UI)                                                   │
│  • Authentication    • Home           • Product Details         │
│  • Cart & Checkout   • Orders         • Profile                │
│  • Address Manager   • Rider Dashboard • Admin Panel           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT                             │
├─────────────────────────────────────────────────────────────────┤
│  Riverpod Providers                                             │
│  • AuthProvider       • CartProvider      • OrderProvider       │
│  • ProductProvider    • UserProvider      • LocationProvider    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BUSINESS LOGIC                               │
├─────────────────────────────────────────────────────────────────┤
│  Services & Repositories                                        │
│  • ApiService         • AuthRepository    • CartRepository      │
│  • PaymentService     • LocationService   • NotificationService │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                   │
├─────────────────────────────────────────────────────────────────┤
│  • HTTP Client (Dio)                                            │
│  • WebSocket Client (socket_io_client)                          │
│  • Local Storage (Hive)                                         │
│  • Secure Storage (flutter_secure_storage)                      │
└─────────────────────────────────────────────────────────────────┘
```

#### Key Design Patterns
1. **Clean Architecture:** Clear separation of concerns (UI → Logic → Data)
2. **Repository Pattern:** Abstraction over data sources (API, cache, local DB)
3. **Provider Pattern:** Reactive state management with Riverpod
4. **Dependency Injection:** Constructor injection for testability

---

### 3.2 Backend Architecture (NestJS)

```
┌─────────────────────────────────────────────────────────────────┐
│                    API GATEWAY LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│  • HTTP Controllers (REST)                                      │
│  • WebSocket Gateways (Socket.io)                               │
│  • GraphQL Resolvers (Future)                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MIDDLEWARE LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  • Authentication Guard (JWT)                                   │
│  • Authorization Guard (RBAC)                                   │
│  • Rate Limiting                                                │
│  • Request Validation (class-validator)                         │
│  • Logging & Monitoring                                         │
│  • Error Handling                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BUSINESS LOGIC LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│  Domain Modules                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Auth Module                                           │   │
│  │  • OTP Generation/Verification  • JWT Token Management │   │
│  │  • Session Management           • Role Management      │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Product Module                                        │   │
│  │  • Product CRUD         • Inventory Management         │   │
│  │  • Category Management  • Search & Filtering           │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Order Module                                          │   │
│  │  • Order Creation       • State Machine                │   │
│  │  • Order Assignment     • Order Tracking               │   │
│  │  • Cancellation Logic   • Refund Processing            │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Payment Module                                        │   │
│  │  • Razorpay Integration • Payment Verification         │   │
│  │  • Webhook Handling     • Refund Processing            │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Delivery Module                                       │   │
│  │  • Rider Management     • Route Optimization           │   │
│  │  • Slot Management      • Real-time Tracking           │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DATA ACCESS LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│  • TypeORM Repositories                                         │
│  • Redis Cache Manager                                          │
│  • Query Builders & Raw SQL (Optimized)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│  • Database Connections (PostgreSQL Pool)                       │
│  • Cache Connections (Redis Cluster)                            │
│  • External API Clients (Razorpay, FCM, SMS, Maps)              │
│  • File Storage (Cloudflare R2)                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Key Design Patterns
1. **Layered Architecture:** Clear separation of API, business logic, and data access
2. **Dependency Injection:** NestJS native DI container
3. **CQRS (Future):** Command-Query Responsibility Segregation for complex domains
4. **Event-Driven:** Asynchronous events for order state changes, notifications
5. **Repository Pattern:** Abstraction over TypeORM for testability

---

## 4. Data Flow Architecture

### 4.1 Order Placement Flow

```
Customer App                Backend                    External Services
     │                         │                              │
     │  1. Add to Cart         │                              │
     ├────────────────────────>│                              │
     │  (POST /api/cart/add)   │                              │
     │                         │                              │
     │  2. Cart Synced         │                              │
     │<────────────────────────┤                              │
     │  (Redis + PostgreSQL)   │                              │
     │                         │                              │
     │  3. Initiate Checkout   │                              │
     ├────────────────────────>│                              │
     │  (POST /api/orders)     │                              │
     │                         │                              │
     │                         │  4. Validate Inventory       │
     │                         ├─────────────────────────────>│
     │                         │     (PostgreSQL)             │
     │                         │                              │
     │                         │  5. Create Order (PENDING)   │
     │                         │<─────────────────────────────┤
     │                         │                              │
     │                         │  6. Initiate Payment         │
     │                         ├─────────────────────────────>│
     │                         │     (Razorpay API)           │
     │                         │                              │
     │  7. Payment Gateway URL │                              │
     │<────────────────────────┤                              │
     │                         │                              │
     │  8. Complete Payment    │                              │
     ├─────────────────────────┼─────────────────────────────>│
     │  (Razorpay Checkout)    │                              │
     │                         │                              │
     │                         │  9. Webhook (Payment Success)│
     │                         │<─────────────────────────────┤
     │                         │                              │
     │                         │  10. Update Order (CONFIRMED)│
     │                         │     Reserve Inventory        │
     │                         │     Assign Rider             │
     │                         │                              │
     │  11. Order Confirmed    │                              │
     │<────────────────────────┤                              │
     │  (WebSocket Push)       │                              │
     │                         │                              │
     │  12. Real-time Tracking │                              │
     │<═══════════════════════>│  13. FCM Push Notifications  │
     │  (WebSocket)            ├─────────────────────────────>│
     │                         │     (Firebase Cloud Messaging)│
```

### 4.2 Real-Time Tracking Flow

```
Rider App              Backend (Socket.io)          Customer App
     │                         │                         │
     │  1. Connect WebSocket   │                         │
     ├────────────────────────>│  2. Connect WebSocket   │
     │  (Auth: JWT)            │<────────────────────────┤
     │                         │  (Auth: JWT)            │
     │                         │                         │
     │  3. Update Location     │                         │
     ├────────────────────────>│                         │
     │  (lat, lng every 10s)   │                         │
     │                         │  4. Broadcast Location  │
     │                         ├────────────────────────>│
     │                         │  (order_location_update)│
     │                         │                         │
     │  5. Update Status       │                         │
     │  (PICKED_UP)            │                         │
     ├────────────────────────>│                         │
     │                         │  6. Broadcast Status    │
     │                         ├────────────────────────>│
     │                         │  (order_status_update)  │
     │                         │                         │
     │                         │  7. Save to DB          │
     │                         │  (order_status_logs)    │
```

---

## 5. Security Architecture

### 5.1 Authentication Flow

```
┌────────────────────────────────────────────────────────────┐
│                  AUTHENTICATION FLOW                       │
└────────────────────────────────────────────────────────────┘

1. User enters phone number
   └─> POST /api/auth/send-otp
       ├─> Validate phone format
       ├─> Generate 6-digit OTP
       ├─> Store in Redis (5-min TTL)
       └─> Send via SMS Gateway

2. User enters OTP
   └─> POST /api/auth/verify-otp
       ├─> Validate OTP from Redis
       ├─> Create/fetch user record
       ├─> Generate JWT access token (15-min expiry)
       ├─> Generate refresh token (30-day expiry, stored in DB)
       └─> Return tokens + user profile

3. Subsequent requests
   └─> Authorization: Bearer <access_token>
       ├─> JWT verification (signature, expiry)
       ├─> Extract user ID & role
       └─> Attach to request context

4. Token refresh
   └─> POST /api/auth/refresh
       ├─> Validate refresh token (DB lookup)
       ├─> Generate new access token
       └─> Rotate refresh token (optional)
```

### 5.2 Authorization (RBAC)

```
┌────────────────────────────────────────────────────────────┐
│              ROLE-BASED ACCESS CONTROL                     │
└────────────────────────────────────────────────────────────┘

Roles:
  • CUSTOMER    → Browse, order, track own orders
  • RIDER       → View assigned orders, update status, location
  • ADMIN       → Full access (CRUD products, manage orders/users/riders)
  • SUPER_ADMIN → Admin + system config, analytics

Permissions Matrix:

Resource            | CUSTOMER | RIDER | ADMIN | SUPER_ADMIN
--------------------|----------|-------|-------|------------
GET /products       | ✓        | ✓     | ✓     | ✓
POST /orders        | ✓        | ✗     | ✓     | ✓
GET /orders/:id     | Own only | Assigned | All | All
PATCH /orders/:id   | Cancel   | Status | All   | All
POST /admin/products| ✗        | ✗     | ✓     | ✓
GET /admin/analytics| ✗        | ✗     | ✓     | ✓
POST /admin/users   | ✗        | ✗     | ✗     | ✓

Implementation:
  • @Roles('ADMIN', 'SUPER_ADMIN') decorator on controllers
  • RolesGuard checks req.user.role against allowed roles
  • Row-level security for customer/rider-owned resources
```

---

## 6. Scalability Design

### 6.1 Horizontal Scaling

```
┌────────────────────────────────────────────────────────────┐
│                  LOAD BALANCER (Nginx)                     │
│                  (Round-robin / Least Connections)         │
└────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ NestJS App 1 │  │ NestJS App 2 │  │ NestJS App N │
│ (Container)  │  │ (Container)  │  │ (Container)  │
└──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ▼
        ┌─────────────────────────────────┐
        │  Shared State (Redis Cluster)   │
        │  • Sessions                     │
        │  • Cache                        │
        │  • WebSocket Rooms              │
        └─────────────────────────────────┘
```

**Key Considerations:**
- **Stateless Application Servers:** All session state in Redis
- **Sticky Sessions (WebSocket):** Nginx IP hash for Socket.io
- **Database Connection Pooling:** Max 100 connections per app instance
- **Auto-scaling:** CPU > 70% → spawn new container

### 6.2 Caching Strategy

```
┌────────────────────────────────────────────────────────────┐
│                    CACHING LAYERS                          │
└────────────────────────────────────────────────────────────┘

Layer 1: CDN Cache (Cloudflare)
  • Static assets (images, CSS, JS)
  • TTL: 7 days
  • Cache-Control: public, max-age=604800

Layer 2: Application Cache (Redis)
  • Product catalog (TTL: 5 minutes)
  • Category tree (TTL: 10 minutes)
  • User sessions (TTL: session lifetime)
  • Cart data (TTL: 24 hours)
  • Hot data queries (dynamic TTL)

Layer 3: Database Query Cache (PostgreSQL)
  • Materialized views for analytics
  • Refresh: Every 1 hour

Cache Invalidation:
  • Event-driven: Product update → clear product cache
  • Time-based: TTL expiry
  • Manual: Admin trigger (cache-busting)
```

### 6.3 Database Optimization

```
┌────────────────────────────────────────────────────────────┐
│              DATABASE SCALING STRATEGY                     │
└────────────────────────────────────────────────────────────┘

Phase 1: Vertical Scaling (Current)
  • Single PostgreSQL instance
  • 8 vCPU, 16GB RAM, 200GB SSD
  • Supports ~5,000 orders/day

Phase 2: Read Replicas (50K+ orders/day)
  • Master (writes) + 2 Read Replicas
  • Read-heavy queries → replicas
  • TypeORM replication support

Phase 3: Partitioning (500K+ orders/day)
  • Partition orders table by month (date)
  • Partition order_items by order_id (hash)
  • Improves query performance on large tables

Phase 4: Sharding (1M+ orders/day)
  • Shard by geography (city_id)
  • Each shard = independent database
  • Application-level routing

Indexing Strategy:
  ✓ Composite indexes on frequent queries
  ✓ Partial indexes for filtered queries
  ✓ GIN indexes for JSONB columns
  ✓ Full-text search indexes (product names, descriptions)

Query Optimization:
  ✓ N+1 query elimination (eager loading)
  ✓ Query result pagination (limit/offset)
  ✓ Database connection pooling (100 max)
```

---

## 7. Resilience & Fault Tolerance

### 7.1 Error Handling

```
┌────────────────────────────────────────────────────────────┐
│                  ERROR HANDLING STRATEGY                   │
└────────────────────────────────────────────────────────────┘

Application Errors:
  • Validation errors → 400 Bad Request
  • Authentication errors → 401 Unauthorized
  • Authorization errors → 403 Forbidden
  • Not found → 404 Not Found
  • Server errors → 500 Internal Server Error

Error Response Format:
{
  "success": false,
  "error": {
    "code": "INVALID_OTP",
    "message": "The OTP you entered is incorrect or expired.",
    "timestamp": "2026-06-12T17:15:00Z",
    "requestId": "req_abc123"
  }
}

Retry Strategy:
  • Idempotent operations (GET) → 3 retries with exponential backoff
  • Payment gateway calls → 2 retries (idempotency key)
  • SMS/FCM → 3 retries with 5s delay
```

### 7.2 Circuit Breaker Pattern

```
External Service Call (e.g., Razorpay)
         │
         ▼
┌────────────────────┐
│  Circuit Breaker   │
│  State: CLOSED     │◄── Success rate > 90%
└────────────────────┘
         │
         ▼ Failure rate > 10% (last 100 calls)
┌────────────────────┐
│  Circuit Breaker   │
│  State: OPEN       │◄── Fast-fail for 30s
└────────────────────┘
         │
         ▼ After 30s timeout
┌────────────────────┐
│  Circuit Breaker   │
│  State: HALF_OPEN  │◄── Try 1 request
└────────────────────┘
         │
         ├─> Success → CLOSED
         └─> Failure → OPEN
```

### 7.3 Backup & Disaster Recovery

```
┌────────────────────────────────────────────────────────────┐
│               BACKUP & RECOVERY STRATEGY                   │
└────────────────────────────────────────────────────────────┘

Database Backups:
  • Full backup: Daily at 2 AM UTC (automated)
  • Incremental backup: Every 6 hours
  • WAL (Write-Ahead Logging) archiving: Continuous
  • Retention: 30 days
  • Storage: Cloudflare R2 (encrypted)

Recovery Time Objective (RTO): 2 hours
Recovery Point Objective (RPO): 1 hour

Disaster Scenarios:
  1. Database corruption → Restore from latest backup
  2. Datacenter failure → Failover to standby region (manual)
  3. Application crash → Auto-restart (Docker health checks)
  4. Redis cache failure → Degrade gracefully (read from DB)
```

---

## 8. Monitoring & Observability

### 8.1 Monitoring Stack

```
┌────────────────────────────────────────────────────────────┐
│                  OBSERVABILITY STACK                       │
└────────────────────────────────────────────────────────────┘

Metrics Collection:
  • Application: NestJS + Prometheus client
  • System: Node Exporter (CPU, memory, disk, network)
  • Database: PostgreSQL Exporter
  • Redis: Redis Exporter

Metrics Visualization:
  • Grafana dashboards (real-time)
  • Key metrics: RPS, latency, error rate, DB connections

Logging:
  • Centralized: Winston → File → Log aggregation
  • Structured JSON logs
  • Log levels: ERROR, WARN, INFO, DEBUG
  • Retention: 90 days

Alerting:
  • Critical: API error rate > 5% → PagerDuty
  • High: CPU > 80% for 5 min → Slack
  • Medium: Order processing delay > 2 min → Email

Tracing:
  • Distributed tracing (future): OpenTelemetry + Jaeger
  • Correlation IDs for request tracking
```

### 8.2 Key Performance Indicators (KPIs)

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| API Response Time (P95) | <200ms | >500ms |
| Database Query Time (P95) | <50ms | >200ms |
| Order Processing Time | <30s | >60s |
| WebSocket Connection Success Rate | >99% | <95% |
| Payment Success Rate | >97% | <90% |
| Uptime | 99.9% | <99.5% |

---

## 9. Technology Stack Summary

### 9.1 Frontend Stack

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| Framework | Flutter | 3.9+ | Cross-platform mobile development |
| State Management | Riverpod | 2.x | Reactive state management |
| HTTP Client | Dio | 5.x | REST API communication |
| WebSocket | socket_io_client | 2.x | Real-time communication |
| Local Storage | Hive | 2.x | NoSQL local database |
| Secure Storage | flutter_secure_storage | 8.x | Encrypted key-value storage |
| Maps | google_maps_flutter | 2.x | Map display, location picker |
| Location | geolocator | 10.x | GPS location services |
| UI Components | Material 3 | - | Design system |
| Payment | Razorpay SDK | 1.x | Payment gateway integration |
| Push Notifications | firebase_messaging | 14.x | FCM integration |

### 9.2 Backend Stack

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| Runtime | Node.js | 20 LTS | JavaScript runtime |
| Framework | NestJS | 10.x | Enterprise-grade Node.js framework |
| Language | TypeScript | 5.x | Type-safe JavaScript |
| Database | PostgreSQL | 15.x | Relational database |
| Cache | Redis | 7.x | In-memory cache, session store |
| ORM | TypeORM | 0.3.x | Database abstraction |
| Authentication | JWT | - | Token-based auth |
| Validation | class-validator | 0.14.x | DTO validation |
| Documentation | Swagger | 7.x | API documentation |
| Real-time | Socket.io | 4.x | WebSocket server |
| Testing | Jest | 29.x | Unit & integration testing |

### 9.3 Infrastructure Stack

| Category | Technology | Purpose |
|----------|-----------|---------|
| Server | Ubuntu 22.04 LTS | Operating system |
| Containerization | Docker | Application packaging |
| Orchestration | Docker Compose | Multi-container management |
| Reverse Proxy | Nginx | Load balancing, SSL termination |
| CDN | Cloudflare | Edge caching, DDoS protection |
| SSL | Let's Encrypt | Free SSL certificates |
| Storage | Cloudflare R2 | S3-compatible object storage |
| CI/CD | GitHub Actions | Automated deployment |
| Monitoring | Grafana + Prometheus | Metrics & dashboards |
| Logging | Winston | Structured logging |

---

## 10. Future Architecture Roadmap

### Phase 1 (Current): Modular Monolith
- Single NestJS application
- Supports 10K concurrent users
- Deployment: Single VPS + Docker

### Phase 2 (6-12 months): Microservices Decomposition
- Extract high-traffic modules: Orders, Delivery, Notifications
- Message queue (RabbitMQ/Kafka) for async communication
- API Gateway (Kong/AWS API Gateway)

### Phase 3 (12-24 months): Cloud-Native
- Migrate to Kubernetes (GKE/EKS)
- Serverless functions (AWS Lambda) for event processing
- Multi-region deployment for low latency

### Phase 4 (24-36 months): Advanced Capabilities
- GraphQL API for flexible client queries
- Real-time data streaming (Kafka Streams)
- Machine learning: demand forecasting, dynamic pricing
- Advanced analytics (BigQuery/Snowflake)

---

**Next Steps:**
- [Technical Specification](./TECHNICAL_SPECIFICATION.md) — Deep dive into implementation
- [Database Design](./DATABASE_DESIGN.md) — Schema and relationships
- [API Documentation](./API_DOCUMENTATION.md) — Endpoint specifications
- [Security Architecture](./SECURITY_ARCHITECTURE.md) — Security controls in depth

---

*Document Classification: Confidential — Technical Documentation*
