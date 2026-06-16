# Authentication Security Report

**Date:** 2026-06-12

## JWT Access Tokens

| Control | Before | After |
|---------|--------|-------|
| Algorithm whitelist | ✅ HS256 (`auth.middleware.js:48-52`) | ✅ Unchanged |
| Issuer check | ✅ `meatvo-app` | ✅ Unchanged |
| Audience check | ✅ `meatvo-users` | ✅ Unchanged |
| Expiration check | ✅ via `jwt.verify` | ✅ Unchanged |
| Token type check | ❌ Missing in `authenticateToken` | ✅ **FIXED** `enhancedAuth.middleware.js` |
| Blacklist on logout | ✅ Redis fail-closed | ✅ Unchanged |

## JWT Refresh Tokens

| Control | Before | After |
|---------|--------|-------|
| Algorithm/iss/aud | ❌ Bare `jwt.verify` | ✅ **FIXED** `auth.service.js` |
| Type check (`refresh`) | ❌ Missing | ✅ **FIXED** |
| Timing-safe hash compare | ❌ `!==` | ✅ **FIXED** `auth.controller.js` |
| Rate limiting | ❌ Global only | ✅ **FIXED** 10/min `refreshTokenRateLimiter` |
| Default expiry | 30d | ✅ **7d** (env override still supported) |
| Rotation reuse detection | ❌ TOCTOU race | ⚠️ **OPEN** — needs DB transaction |

## Logout Flow

- Clears `refresh_token_hash` in DB ✅
- Blacklists access token in Redis ✅
- Gap: other devices' access tokens valid until expiry (~15m) — acceptable

## Password Reset

- **Not implemented** — no routes exist. Utilities in `utils/jwt.js` are dead code.

## OTP Flow

- HMAC-SHA256 with `OTP_HASH_SECRET` ✅
- `crypto.timingSafeEqual` on verify ✅
- Redis TTL + max attempts ✅
- Minimum 6-digit OTP enforced ✅ **FIXED**
- Rate limit fail-closed on Redis error ✅ **FIXED**

## Admin Authentication

- Admin API: `protect` + `rbac(ADMIN)` ✅
- Admin bootstrap via `ADMIN_PHONES` env ⚠️ **OPEN** — SIM-swap risk
- No mandatory admin MFA ⚠️ **OPEN**

## MFA

| Control | Before | After |
|---------|--------|-------|
| Disable without verification | ❌ Critical | ✅ **FIXED** — TOTP required |
| Enable when already enabled | ❌ Overwrite possible | ✅ **FIXED** |
| `mfaSecret` on `req.user` | ❌ Leaked | ✅ **FIXED** — `_mfaSecret` internal only |
| MFA rate limit fail-closed | ❌ Fail open | ✅ **FIXED** |
| MFA secret encryption at rest | ❌ Plaintext DB | ⚠️ **OPEN** |
| Backup code CSPRNG | ❌ `Math.random` | ✅ **FIXED** |

## Fixes Applied

1. `enhancedAuth.middleware.js` — access token type check, MFA secret stripping
2. `auth.service.js` — hardened refresh verification, 7d default expiry
3. `auth.controller.js` — timing-safe refresh hash, min OTP length 6
4. `enhanced-auth.routes.js` — MFA disable/enable/verify hardening
5. `auth.routes.js` — refresh token rate limiter
6. `auth.validation.js` — min OTP 6, MFA schemas
7. `mfa.service.js` — CSPRNG backup codes
