# Environment Variables Report

## P0 — App Won't Start (Production)

| Variable | Used In | Required | Default | Criticality |
|----------|---------|----------|---------|-------------|
| `DB_HOST` | `postgres.js` | Yes | localhost | Critical |
| `DB_PORT` | `postgres.js` | Yes | 5432 | Critical |
| `DB_NAME` | `postgres.js` | Yes | meatvo | Critical |
| `DB_USER` | `postgres.js` | Yes | postgres | Critical |
| `DB_PASSWORD` | `postgres.js` | Yes | — | Critical |
| `DATABASE_URL` | `validateEnv.js` | Yes (prod) | — | Critical |
| `REDIS_URL` | `redis.js` | Yes (prod) | redis://localhost:6379 | Critical |
| `JWT_ACCESS_SECRET` | auth middleware | Yes | — | Critical |
| `JWT_REFRESH_SECRET` | auth.service.js | Yes | — | Critical |
| `OTP_HASH_SECRET` | auth.controller.js | Yes | — | Critical |
| `PORT` | index.js | Yes | **8080** | Critical |

## P0 — Payments

| Variable | Used In | Required | Notes |
|----------|---------|----------|-------|
| `PHONEPE_MERCHANT_ID` | payments.controller.js | Yes | Throws in prod if missing |
| `PHONEPE_SALT_KEY` | phonepeChecksum.js | Yes | Backend only |
| `PHONEPE_SALT_INDEX` | phonepeChecksum.js | Yes | Default `1` |
| `PHONEPE_REDIRECT_URL` | payments.controller.js | Yes | Must be HTTPS in prod |
| `PHONEPE_WEBHOOK_URL` | payments.controller.js | Yes | Must be HTTPS in prod |

## P1 — OTP / SMS

| Variable | Runtime Name | Notes |
|----------|--------------|-------|
| `MSG91_AUTH_KEY` | **Canonical** | Docker/K8s updated from `MSG91_API_KEY` |
| `MSG91_TEMPLATE_ID` | Required in prod | OTP template |
| `MSG91_SENDER_ID` | Default MEATVO | DLT registered |
| `SMS_PROVIDER` | Default msg91 | |

## P1 — Operations

| Variable | Default (prod) | Notes |
|----------|----------------|-------|
| `TRUST_PROXY` | true (VPS) | Required behind Nginx |
| `ENFORCE_HTTPS` | true after SSL | Set false until Phase 3 |
| `CORS_ORIGINS` | — | Production domain(s) |
| `CORS_ALLOW_NULL_ORIGIN` | **false** | Mobile uses no Origin header |
| `SENTRY_DSN` | — | Now initialized at boot |

## Flutter (via --dart-define)

| Variable | Required Prod | Notes |
|----------|---------------|-------|
| `API_BASE_URL` | Yes | Not bundled in APK |
| `GOOGLE_MAPS_API_KEY` | Yes | Also in gradle.properties |
| `APP_ENV` | Yes | `production` for release |

**Removed from Flutter**: `PHONEPE_SALT_KEY`, `PHONEPE_MERCHANT_ID`

## Templates

- Backend VPS: `backend/.env.vps.example`
- Flutter prod: `old_meatvo/env.production.example.json`
- Manifest: `shared/env-manifest.json` (PORT default = 8080)
