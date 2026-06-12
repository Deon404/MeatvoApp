# Production Discovery Report — Meatvo (KillExotic)

**Date:** 2026-06-12  
**Scope:** Full monorepo audit for Hostinger KVM VPS (Ubuntu 24.04)

---

## Architecture Overview

Meatvo is a hyperlocal raw-meat delivery platform (India). Monorepo structure:

| Path | Purpose |
|------|---------|
| `backend/` | Node.js REST API + Socket.io + PostgreSQL/Redis |
| `old_meatvo/` | Flutter customer/rider/admin mobile app |
| `admin/`, `customer/`, `delivery/` | Web SPAs served by backend |
| `shared/` | Shared env manifest (`env-manifest.json`) |
| `scripts/` | VPS deployment, backup, SSL, Nginx configs |

**Traffic flow:** Client → Nginx (:443) → PM2 → Node.js (:8080) → PostgreSQL + Redis

---

## Backend Framework

- **Runtime:** Node.js 20 LTS (VPS target)
- **Framework:** Express 5.0.1 (CommonJS)
- **Entry:** `backend/index.js` (default port 8080)
- **Modules:** 15 feature modules under `backend/src/modules/`
- **Real-time:** Socket.io on path `/ws`
- **Validation:** Joi, Zod, express-validator
- **Security:** Helmet, CORS, rate limiting, CSRF, RBAC, JWT

---

## Frontend Framework

| Client | Stack |
|--------|-------|
| Flutter (`old_meatvo/`) | Flutter 3.9+, Riverpod, Dio, Socket.io, Google Maps |
| Web SPAs | Static HTML/JS served from `/admin`, `/customer`, `/delivery` |

---

## Database Technology

- **Primary:** PostgreSQL (native on VPS)
- **Cache:** Redis via `ioredis` (cart, OTP, rate limits, token blacklist)
- **Schema:** `backend/src/db/schema.sql` + `ensureSchema.js` (runtime patches)
- **Migrations:** `backend/migrations/*.sql`, `run-migrations.js`, `migrate_order_statuses.js`
- **Tables:** 14+ core tables (users, orders, products, delivery_partners, etc.)

---

## Authentication System

- Phone OTP via MSG91
- JWT access + refresh tokens (HS256)
- Redis-backed token blacklist on logout
- Optional MFA (TOTP via speakeasy)
- Role-based access: `admin`, `customer`, `delivery`

---

## Payment Integrations

- **PhonePe** gateway: initiate, verify, webhook
- Checksum signing via `phonepeChecksum.js` (base64 response field for webhooks)
- COD fallback supported

---

## External APIs

| Service | Purpose |
|---------|---------|
| MSG91 | OTP SMS |
| PhonePe | Online payments |
| Google Maps | Geocoding, directions, delivery UI |
| Firebase | Web push config (FCM tokens stored; server push partial) |
| Sentry | Error tracking (initialized at boot) |
| AWS SSM/S3 | Optional secrets and uploads |

---

## Environment Variables

110+ variables documented in `ENVIRONMENT_AUDIT.md` and `shared/env-manifest.json`.  
Critical production: `DATABASE_URL`, `REDIS_URL`, JWT secrets, `OTP_HASH_SECRET`, MSG91, PhonePe, `SENTRY_DSN`.

---

## Deployment Dependencies

- Ubuntu 24.04, Node.js 20, PM2, PostgreSQL 16, Redis 7, Nginx
- Certbot for SSL
- UFW firewall (22, 80, 443 only — **not** 8080)

---

## Build Process

```bash
# Backend
cd backend && npm ci --omit=dev

# Flutter (release)
cd old_meatvo && flutter build appbundle --release --dart-define-from-file=env.production.json
```

---

## Runtime Dependencies

See `backend/package.json`. Key: `express`, `pg`, `ioredis`, `socket.io`, `jsonwebtoken`, `helmet`, `winston`, `@sentry/node`.

---

## Production Blockers (Identified)

| ID | Issue | Status |
|----|-------|--------|
| SEC-01 | Order status IDOR | **Fixed** |
| SEC-02 | Token blacklist bypass | **Fixed** |
| SEC-03 | PhonePe webhook signature | **Fixed** (verify in sandbox) |
| DB-01–03 | Missing `updated_at` columns | **Fixed** (migration 006 + schema) |
| DEP-01 | SSL script missing | **Fixed** (`vps-phase3-ssl.sh`, `setup-ssl.sh`) |
| ENV-03 | Localhost PhonePe URLs in templates | **Fixed** (HTTPS placeholders) |
| SEC-05/07 | Flutter release signing, bundled `.env` | **Partial** — operator must configure keystore |

---

## Security Risks

- Firebase API key in committed `google-services.json` — restrict in Firebase console
- Health endpoints IP-restricted — configure monitoring IP allowlist
- Minimal test coverage for payment flow

---

## Missing Infrastructure (Operator)

- Live VPS deployment not yet executed
- SSL certificate not yet issued
- Backup cron not yet scheduled
- External uptime monitoring not configured

---

## Related Documents

- [ENVIRONMENT_AUDIT.md](./ENVIRONMENT_AUDIT.md)
- [SECURITY_AUDIT.md](./SECURITY_AUDIT.md)
- [DATABASE_AUDIT.md](./DATABASE_AUDIT.md)
- [PRODUCTION_CHECKLIST.md](./PRODUCTION_CHECKLIST.md)
- [FINAL_DEPLOYMENT_REPORT.md](./FINAL_DEPLOYMENT_REPORT.md)
