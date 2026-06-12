# Environment Audit — Meatvo Backend

**Date:** 2026-06-12  
**Source of truth:** `backend/src/config/env.constants.js`, `validateEnv.js`, `shared/env-manifest.json`

---

## Classification Legend

| Class | Meaning |
|-------|---------|
| **Required Production** | App exits or core feature fails without it |
| **Required Development** | Needed for local dev with full features |
| **Optional** | Feature-specific or has safe default |

---

## Required Production

| Variable | Purpose | Notes |
|----------|---------|-------|
| `NODE_ENV` | Runtime mode | Must be `production` |
| `PORT` | Listen port | Default `8080` |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | PostgreSQL | Validated by `validateEnv` |
| `DATABASE_URL` | PG connection string | Alternative to split vars |
| `REDIS_URL` | Redis connection | **Required** in production; exits if missing |
| `JWT_ACCESS_SECRET` | Access token signing | Min 32 bytes recommended |
| `JWT_REFRESH_SECRET` | Refresh token signing | Must differ from access secret |
| `OTP_HASH_SECRET` | OTP HMAC at rest | Required for auth |
| `MSG91_AUTH_KEY` | SMS OTP | **Not** `MSG91_API_KEY` at runtime |
| `MSG91_TEMPLATE_ID` or `MSG91_OTP_TEMPLATE_ID` | DLT template | At least one required |
| `MSG91_SENDER_ID` | DLT header | Default `MEATVO` |
| `PHONEPE_MERCHANT_ID` | Payments | |
| `PHONEPE_SALT_KEY` | Payment checksum | **Backend only** — never in Flutter |
| `PHONEPE_SALT_INDEX` | Salt index | Default `1` |
| `PHONEPE_REDIRECT_URL` | Post-payment redirect | Must be HTTPS in prod |
| `PHONEPE_WEBHOOK_URL` | Webhook callback | Must be HTTPS in prod |
| `GOOGLE_MAPS_API_KEY` | Maps/geocoding | Billing must be enabled |
| `FIREBASE_API_KEY` | Push config | Restrict in Firebase console |
| `FIREBASE_VAPID_KEY` | Web push | Required when `FIREBASE_API_KEY` set |
| `SENTRY_DSN` | Error tracking | Initialized in `index.js` |
| `TRUST_PROXY` | Behind Nginx | Must be `true` on VPS |
| `CORS_ORIGINS` | Allowed origins | Production HTTPS domain(s) |

---

## Required Development

| Variable | Purpose |
|----------|---------|
| `DB_*` / `DATABASE_URL` | Local PostgreSQL |
| `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET` | Token signing |
| `OTP_HASH_SECRET` | OTP hashing |
| `PORT` | Default 8080 |

Dev may run without `REDIS_URL` (memory fallback) and without MSG91 (console OTP if configured).

---

## Optional (Selected)

| Variable | Default | Purpose |
|----------|---------|---------|
| `ENFORCE_HTTPS` | `true` in prod | Redirect HTTP→HTTPS |
| `CORS_ALLOW_NULL_ORIGIN` | `false` prod | Mobile/curl without Origin |
| `OTP_LENGTH` / `MSG91_OTP_LENGTH` | `6` | OTP digit count |
| `PM2_INSTANCES` | `1` | Cluster mode |
| `ELASTICSEARCH_URL` | localhost:9200 | Log aggregation |
| `AWS_S3_BUCKET` | — | Upload storage |
| `DEV_AUTH_BYPASS_*` | disabled | **Never in production** |

Full list: `shared/env-manifest.json` (50+ documented keys).

---

## Issues Detected & Resolution

| Issue | Severity | Status |
|-------|----------|--------|
| `MSG91_AUTH_KEY` vs `MSG91_API_KEY` naming | High | Standardized on `MSG91_AUTH_KEY` |
| PORT default 8080 vs manifest 5000 | Medium | Aligned to **8080** everywhere |
| `PHONEPE_SALT_KEY` in Flutter env | Critical | Removed from mobile manifest |
| `.env` bundled in Flutter APK | Critical | Use `--dart-define-from-file` |
| Placeholder `SENTRY_DSN` in VPS template | Medium | Replace with real DSN |
| `TRUST_PROXY` missing in old templates | High | Added to `.env.vps.example` |

---

## Hardcoded Secrets Scan

- **Backend JS:** No production secrets hardcoded ✓
- **Flutter:** `google-services.json` contains Firebase key — restrict in console
- **`.env`:** Gitignored ✓
- **Default credentials:** PostgreSQL defaults to `postgres` user only in dev fallbacks

---

## Templates

| File | Use |
|------|-----|
| `backend/.env.example` | Minimal dev/prod reference |
| `backend/.env.production.example` | Full production template |
| `backend/.env.vps.example` | Hostinger KVM with inline comments |

---

## Flutter Environment (Separate)

Flutter reads from `.env` asset or `--dart-define-from-file`. **Never include:**
- `PHONEPE_SALT_KEY`
- `JWT_*_SECRET`
- `OTP_HASH_SECRET`
- `DB_PASSWORD`

Safe in Flutter: `API_BASE_URL`, `GOOGLE_MAPS_API_KEY`, public Firebase config.
