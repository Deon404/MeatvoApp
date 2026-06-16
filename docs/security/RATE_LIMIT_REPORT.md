# Rate Limiting Report

**Date:** 2026-06-12

## Global Limits

| Limiter | Window | Max | Applied To |
|---------|--------|-----|------------|
| `apiRateLimiter` | 15 min | 300/IP | `/api/*` |
| `authIpRateLimiter` | 15 min | 60/IP | `/api/auth/*` |

## Endpoint-Specific Limits

| Endpoint | Limiter | Status |
|----------|---------|--------|
| `POST /auth/send-otp` | `authRoutesIpRateLimiter` + `otpRateLimiter` | ✅ |
| `POST /auth/verify-otp` | `authRoutesIpRateLimiter` + `verifyOtpRateLimiter` | ✅ |
| `POST /auth/refresh-token` | `refreshTokenRateLimiter` (10/min) | ✅ **FIXED** |
| `POST /auth/mfa/*` | `mfaRateLimiter` (5/min) | ✅ **FIXED** (all MFA routes) |
| `POST /payments/initiate\|verify` | `paymentRateLimit` (10/min/user) | ✅ |
| `POST /payments/*/webhook` | `webhookRateLimit` (10/min) | ✅ |
| `/api/admin/*` | `adminRateLimiter` (100/15min) | ✅ **FIXED** |

## Fail-Closed Behavior

| Limiter | Before | After |
|---------|--------|-------|
| `otpRateLimiter` | Uncaught Redis error | ✅ 503 fail-closed |
| `mfaRateLimiter` | Fail open (`next()`) | ✅ 503 fail-closed |

## Gaps (Not Fixed)

| Endpoint | Risk | Priority |
|----------|------|----------|
| `POST /coupons/validate` | Coupon brute-force | Medium |
| `GET /payments/:orderId/status` | Enumeration | Low |
| Socket inbound events | Flood location updates | Medium |

## Fixes Applied

1. `rateLimiter.js` — `refreshTokenRateLimiter`, `adminRateLimiter`, OTP fail-closed
2. `auth.routes.js` — refresh limiter on both refresh endpoints
3. `enhanced-auth.routes.js` — MFA limiter on setup/enable/disable
4. `index.js` — admin rate limiter on admin mounts
