# Implementation Checklist

## Critical Fixes — COMPLETED

### Security
- [x] SEC-01: Order status IDOR — ownership checks in `orders.controller.js`
- [x] SEC-02: Token blacklist on `protect` middleware
- [x] SEC-03: PhonePe webhook signs base64 `response` field
- [x] SEC-04: OTP increased to 6 digits
- [x] SEC-05: Android release signing via `MEATVO_KEYSTORE_*` properties
- [x] SEC-06: Cleartext HTTP restricted (domain-config for dev hosts only)
- [x] SEC-07: `.env` removed from Flutter assets; use `--dart-define-from-file`
- [x] SEC-08: Firebase key restriction guide (`FIREBASE_SECURITY.md`)
- [x] SEC-09: `CORS_ALLOW_NULL_ORIGIN=false` default in production
- [x] SEC-10: Timing-safe compare for OTP hash and PhonePe checksum

### Database
- [x] DB-01–03: `updated_at` columns in `ensureSchema.js` + migration 006
- [x] DB-04: Extended `order_status` enum values in `ensureSchema.js`
- [x] DB-05: `schema_migrations` table
- [x] DB-06: `rider_earnings_history` BIGINT FKs

### Deployment
- [x] DEP-01: `scripts/vps-phase3-ssl.sh`
- [x] DEP-02: Port 8080 removed from UFW
- [x] DEP-03: `docs/DEPLOYMENT_FRONTEND.md`
- [x] DEP-05: `scripts/backup/postgres-backup.sh`
- [x] DEP-06: Sentry initialized in `index.js`
- [x] DEP-08: Redis `requirepass` in Phase 1 setup

### Configuration
- [x] ENV-01: `MSG91_AUTH_KEY` standardized (Docker/K8s)
- [x] ENV-02: PORT default aligned to 8080
- [x] ENV-03: `.env.vps.example` HTTPS placeholders
- [x] ENV-04: PhonePe secrets removed from Flutter
- [x] ENV-05: `TRUST_PROXY=true` in VPS template

### Infrastructure
- [x] Graceful shutdown (SIGTERM/SIGINT)
- [x] Redis disconnect on shutdown

## Remaining Manual Steps (Operator)

- [ ] Provision VPS and run Phase 1–3 scripts
- [ ] Fill production `.env` with real secrets
- [ ] Generate Android release keystore
- [ ] Restrict Firebase API key in console
- [ ] Configure PhonePe production merchant credentials
- [ ] Verify MSG91 DLT templates approved
- [ ] Upload Flutter AAB to Play Store internal track
