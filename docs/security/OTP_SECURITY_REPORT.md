# OTP Security Report

**Date:** 2026-06-12

## Auth OTP (Login)

| Control | Status | Location |
|---------|--------|----------|
| OTP hashing (HMAC-SHA256) | ✅ | `auth.controller.js:30-38` |
| Timing-safe comparison | ✅ | `auth.controller.js:56-63` |
| Redis TTL (600s default) | ✅ | `auth.controller.js:17` |
| Max attempts (3 default) | ✅ | `auth.controller.js:18` |
| Rate limiting (send) | ✅ | `otpRateLimiter` — 10/10min |
| Rate limiting (verify) | ✅ | `verifyOtpRateLimiter` |
| Resend protection | ✅ | Send-lock in Redis |
| Account lockout | ✅ | Redis-based `lockout:` keys |
| Single-use OTP | ✅ | Deleted on success |
| Minimum 6 digits | ✅ **FIXED** | `auth.validation.js`, `auth.controller.js` |
| Fail-closed on Redis error | ✅ **FIXED** | `rateLimiter.js` |

## Delivery OTP

| Control | Before | After |
|---------|--------|-------|
| Storage | Plaintext Redis | ✅ HMAC-SHA256 hashed |
| Comparison | `!==` | ✅ `timingSafeEqual` |
| Generation | `Math.random()` | ✅ `crypto.randomInt` |
| Redis `setex` | Broken (not exported) | ✅ Uses `set(key, val, 'EX', ttl)` |
| Single-use | ✅ Delete on verify | ✅ Unchanged |
| Expiry | 10 min | ✅ Unchanged |

## Fixes Applied

1. `auth.controller.js` — minimum OTP length 6
2. `auth.validation.js` — `Math.max(6, OTP_LENGTH)`
3. `rateLimiter.js` — OTP limiter fail-closed
4. `deliveryProof.service.js` — full OTP hardening

## Remaining Risks

- Redis keys embed raw phone numbers (`otp:+91…`) — hash phone for key namespace (low priority)
- `OTP_LOG_TO_CONSOLE` can log plaintext in dev — ensure never enabled in staging/prod
