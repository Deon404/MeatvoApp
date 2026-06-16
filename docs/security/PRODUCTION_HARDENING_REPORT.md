# Production Hardening Report

**Date:** 2026-06-12

## HTTP Security Headers

| Control | Status | Location |
|---------|--------|----------|
| Helmet | ✅ | `index.js:68-96` |
| CSP | ✅ Tightened in prod | `index.js` — no `unsafe-eval`/`unsafe-inline` in prod |
| HSTS | ✅ Via Helmet defaults | |
| X-Content-Type-Options (nosniff) | ✅ Helmet | |
| X-Frame-Options | ✅ Helmet | |
| Referrer-Policy | ✅ Helmet | |
| HPP protection | ✅ `index.js:98` | |
| `X-Powered-By` disabled | ✅ **FIXED** | `app.disable('x-powered-by')` |

## HTTPS

| Control | Status |
|---------|--------|
| HTTPS redirect in production | ✅ `index.js:101-110` |
| Configurable via `ENFORCE_HTTPS=false` | ✅ |

## Request Limits

| Control | Value |
|---------|-------|
| JSON body limit | 1MB |
| Trust proxy | Conditional `TRUST_PROXY=true` |

## Process Hardening

| Control | Before | After |
|---------|--------|-------|
| SIGTERM handler | ✅ | ✅ Unchanged |
| SIGINT handler | ✅ | ✅ Unchanged |
| Uncaught exception → shutdown | ✅ | ✅ Unchanged |
| Unhandled rejection → shutdown | ❌ Log only | ✅ **FIXED** in production |
| Graceful shutdown (socket/server/pool/redis) | ✅ | ✅ Unchanged |

## Security Middleware

| Middleware | Wired | Notes |
|------------|-------|-------|
| XSS protection | ✅ | `initializeSecurity` |
| API abuse prevention | ✅ | `initializeSecurity` |
| CSRF protection | ❌ | Defined but not applied — Bearer APIs mitigate |
| Device verification | ❌ | Dead code |

## CORS

- Allowlist from `CORS_ORIGINS` env ✅
- Credentials enabled ✅

## Fixes Applied

1. `index.js` — production CSP, `x-powered-by` disabled, unhandled rejection shutdown, admin rate limiter

## Recommendations Before Deploy

1. Set `NODE_ENV=production`
2. Set `TRUST_PROXY=true` behind Nginx
3. Set `ENFORCE_HTTPS=true` after SSL configured
4. Wire CSRF or document Bearer-only exemption for web SPAs
5. Remove or isolate dead security code (`jwt.security.js`, `otp.security.js`)
