# Meatvo Project Architecture

## Overview

Meatvo is a hyperlocal raw-meat delivery platform (India). Monorepo with Node.js backend, Flutter mobile app, and optional web SPAs.

## Components

| Layer | Technology | Path |
|-------|------------|------|
| REST API | Express 5, Node.js 20 | `backend/` |
| Database | PostgreSQL (raw SQL) | `backend/src/db/` |
| Cache | Redis (`ioredis`) | `backend/src/db/redis.js` |
| Real-time | Socket.io path `/ws` | `backend/src/socket/` |
| Mobile | Flutter 3.9+ | `frontend/` |
| Reverse proxy | Nginx | VPS / Docker |
| Process manager | PM2 | `backend/ecosystem.config.js` |

## External Integrations

- **MSG91** — OTP SMS (`backend/src/utils/msg91.js`)
- **PhonePe** — Online payments (`backend/src/modules/payments/`)
- **Google Maps** — Geocoding, directions, native maps
- **Firebase** — FCM push (client config served from env)
- **Sentry** — Error tracking (initialized at boot)

## Data Flow

```
Flutter App → Nginx :443 → Node :8080 → PostgreSQL
                              ↓
                            Redis (cart, OTP, rate limits, token blacklist)
                              ↓
                         Socket.io /ws (order tracking, rider location)
```

## Deployment Model (Primary)

**VPS bare-metal**: `scripts/vps-phase1-setup.sh` → `vps-phase2-deploy.sh` → `vps-phase3-ssl.sh`

Frontend is served by the backend monolith — see `docs/DEPLOYMENT_FRONTEND.md`.

## Auth Model

OTP via MSG91 → JWT access (15m) + refresh (30d) → RBAC (`admin`, `customer`, `delivery`)

Token blacklist enforced on all `protect` routes via Redis.
