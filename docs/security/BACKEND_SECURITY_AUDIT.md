# Backend Security Audit — Meatvo (KillExotic Backend)

**Audit Date:** 2026-06-12  
**Scope:** `backend/` — full codebase  
**Backups:** `docs/security/backups/20260612_220957/`

---

## Executive Summary

A full security audit was performed across authentication, authorization, payments, database access, file uploads, Redis, Socket.io, admin routes, environment variables, and external API integrations. **21 files were hardened** with safe, non-breaking fixes. Several architectural risks remain that require operational decisions before full production confidence.

---

## Critical Issues

| # | Issue | Location | Status |
|---|-------|----------|--------|
| C1 | MFA disable without TOTP verification | `enhanced-auth.routes.js:59-66` | **FIXED** — requires valid MFA token |
| C2 | Refresh tokens accepted as access tokens | `enhancedAuth.middleware.js:116-121` | **FIXED** — `type === 'access'` enforced |
| C3 | Weak refresh token verification (no iss/aud/alg/type) | `auth.service.js:36-41` | **FIXED** — full JWT constraints |

---

## High Issues

| # | Issue | Location | Status |
|---|-------|----------|--------|
| H1 | Rider `orderId` spoofing via location API | `tracking.service.js:121-147`, `socket.js:128-146` | **FIXED** — assignment check |
| H2 | `join_delivery_room` missing role gate | `socket.js:111-114` | **FIXED** — delivery role required |
| H3 | `mfaSecret` exposed on `req.user` | `enhancedAuth.middleware.js:142-144` | **FIXED** — stripped to `_mfaSecret` |
| H4 | Refresh token hash compared with `!==` | `auth.controller.js:453-455` | **FIXED** — timing-safe compare |
| H5 | No refresh-token rate limiting | `auth.routes.js:18-19` | **FIXED** — 10/min limiter |
| H6 | MFA TOTP secret stored plaintext in DB | `schema.sql:54`, `mfa.service.js` | **OPEN** — needs encryption at rest |
| H7 | `ADMIN_PHONES` env auto-assigns admin role | `auth.controller.js:41-54` | **OPEN** — operational risk |
| H8 | Delivery OTP stored plaintext in Redis | `deliveryProof.service.js:30` | **FIXED** — HMAC hashed |
| H9 | Weak CSP (`unsafe-inline`, `unsafe-eval`) | `index.js:68-95` | **PARTIAL** — tightened in production |
| H10 | CSRF middleware defined but not wired | `security/index.js:40-47` | **OPEN** — Bearer-only APIs mitigate |

---

## Medium Issues

| # | Issue | Location | Status |
|---|-------|----------|--------|
| M1 | `validateOrderOwnership` fails open for unknown roles | `orderState.middleware.js:115-165` | **FIXED** |
| M2 | Slot release allowed for delivery role | `delivery.routes.js:82-87` | **FIXED** — admin only |
| M3 | `addressId` not ownership-validated on order create | `orders.controller.js:225-227` | **FIXED** |
| M4 | OTP/MFA rate limiters fail open on Redis error | `mfaRateLimiter.js:24-27`, `rateLimiter.js:6-21` | **FIXED** — fail closed |
| M5 | OTP length configurable to 4 digits | `auth.validation.js:24` | **FIXED** — minimum 6 |
| M6 | Refresh token expiry 30d default | `auth.service.js:26` | **FIXED** — default 7d |
| M7 | Health probes IP-gated (breaks K8s) | `health.js:15` | **FIXED** — `/ready`, `/live` exempt |
| M8 | IP allowlist substring bypass | `adminOnlyIp.middleware.js:4` | **FIXED** — exact match |
| M9 | Upload MIME-only validation | `file.security.js:72-76` | **FIXED** — magic bytes + ext allowlist |
| M10 | No admin-specific rate limiter | `index.js:229-230` | **FIXED** — 100/15min |
| M11 | Dual JWT stacks (unused `jwt.security.js`) | `security/jwt.security.js` | **OPEN** — dead code |
| M12 | Legacy PhonePe webhook JSON format in prod | `phonepeChecksum.js:48-50` | **OPEN** |
| M13 | Public `/uploads` static serve | `index.js:117` | **OPEN** |
| M14 | Redis cache invalidation literal keys | `products.controller.js:287` | **OPEN** |
| M15 | Socket inbound events lack rate limiting | `socket.js:84-153` | **OPEN** |

---

## Low Issues

| # | Issue | Location | Status |
|---|-------|----------|--------|
| L1 | MFA backup codes use `Math.random()` | `mfa.service.js:172-183` | **FIXED** — `crypto.randomInt` |
| L2 | `x-powered-by` header exposed | `index.js` | **FIXED** — disabled |
| L3 | `unhandledRejection` logs only | `index.js:341-345` | **FIXED** — shutdown in prod |
| L4 | Dead `devLogin` with role elevation | `auth.controller.js:477-516` | **OPEN** — not mounted |
| L5 | `OTP_LOG_TO_CONSOLE` plaintext OTP | `auth.controller.js:247-249` | **OPEN** — env guard exists |
| L6 | Password reset flow not implemented | `utils/jwt.js:68-84` | **N/A** — feature gap |
| L7 | Razorpay/Stripe not implemented | — | **N/A** — PhonePe only |

---

## Areas Verified Secure

- **SQL injection:** All runtime queries use parameterized `$N` placeholders or column allowlists
- **Payment webhooks:** PhonePe `X-VERIFY` signature validation, amount checks, idempotency
- **Order/address/payment IDOR (reads):** Ownership checks on GET `:id` routes
- **Admin RBAC:** All `/api/admin/*` routes use `protect` + `rbac(ADMIN)`
- **OTP auth flow:** HMAC-SHA256 storage, timing-safe compare, Redis TTL, attempt limits
- **Socket connect:** JWT with iss/aud/alg/type, DB user lookup
- **Graceful shutdown:** SIGTERM/SIGINT handlers close socket, server, pool, Redis

---

## Files Modified (Safe Fixes Applied)

See `FINAL_SECURITY_VERDICT.md` for complete list.
