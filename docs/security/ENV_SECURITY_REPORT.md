# Environment Security Report

**Date:** 2026-06-12

## Source Code Scan

**Result: No hardcoded secrets found in committed `backend/**/*.js` source.**

Secrets loaded via:
- `process.env` / `dotenv`
- `config/validateEnv.js` — startup validation
- `config/secrets/secretManager.js` — AWS SSM (optional)

## Required Production Env Vars

| Variable | Purpose |
|----------|---------|
| `JWT_ACCESS_SECRET` | Access token signing |
| `JWT_REFRESH_SECRET` | Refresh token signing |
| `OTP_HASH_SECRET` | OTP HMAC |
| `REDIS_URL` | Required in production (enforced) |
| `DB_*` / `DATABASE_URL` | PostgreSQL connection |
| `PHONEPE_SALT_KEY` | Payment checksum |
| `MSG91_AUTH_KEY` | SMS OTP |

## Local `.env` Risks (gitignored)

| Finding | Severity |
|---------|----------|
| Weak `DEV_AUTH_BYPASS_SECRET` | MEDIUM |
| Real API keys on disk | MEDIUM — rotate if exposed |
| `DB_PASSWORD` weak in dev | LOW |

## Recommendations

1. Never commit `.env` — verified gitignored ✅
2. Use `shared/env-manifest.json` as canonical key list
3. Rotate all secrets before VPS production deploy
4. Set strong `DEV_AUTH_BYPASS_SECRET` or disable `DEV_AUTH_BYPASS_ENABLED`
5. Use AWS SSM / Hostinger env injection for production secrets

## No Secrets Moved (Already Correct)

All application secrets already reference `process.env`. No hardcoded values required relocation.
