# CodeFlow Analysis Report

**Repository:** Local Folder
**Analyzed:** 4/30/2026, 1:46:02 AM

## Summary

| Metric | Value |
|--------|-------|
| Health Score | 77/100 (C) |
| Files | 115 |
| Functions | 406 |
| Lines of Code | 29,745 |
| Dependencies | 224 |
| Unused Functions | 0 |
| Security Issues | 13 |

## Security Issues

### HIGH: SQL Injection Risk
- **File:** `src/modules/admin/admin.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** ``UPDATE categories SET ${sets.join(', ')} WHERE id = $${params.length}`

### HIGH: SQL Injection Risk
- **File:** `src/modules/auth/auth.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `'INSERT INTO otp_logs (phone, otp, expires_at, verified) VALUES ($1, $2, NOW() +`

### HIGH: SQL Injection Risk
- **File:** `src/modules/delivery/slots.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `'UPDATE delivery_slots SET booked = booked + $1 WHERE id = $2',`

### HIGH: SQL Injection Risk
- **File:** `src/modules/delivery/delivery.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.

### HIGH: SQL Injection Risk
- **File:** `src/modules/orders/orders.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `'UPDATE products SET stock = stock + $1 WHERE id = $2',`

### HIGH: SQL Injection Risk
- **File:** `src/utils/jwt.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `'UPDATE users SET token_version = token_version + 1 WHERE id = $1',`

### LOW: Code Comments
- **File:** `docs/webhook-security-fixes.md`
- **Description:** 1 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements
- **File:** `src/socket/socket.js`
- **Description:** 4 console statements found. Remove before production.

### LOW: Code Comments
- **File:** `src/utils/msg91.js`
- **Description:** 3 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements
- **File:** `backend-smoke-check.js`
- **Description:** 5 console statements found. Remove before production.

### LOW: Debug Statements
- **File:** `otp-e2e-check.js`
- **Description:** 6 console statements found. Remove before production.

### LOW: Code Comments
- **File:** `package-lock.json`
- **Description:** 1 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements
- **File:** `run-migrations.js`
- **Description:** 10 console statements found. Remove before production.

## Design Patterns

### Factory
Creates objects without specifying exact class. Enables loose coupling and extensibility.

**Files:** `phonepe-payment-integration.md`, `production-optimizations.md`, `enhancedAuth.middleware.js`, `auth.controller.js`, `auth.service.js`NaN more)

### Observer/Event
Defines a subscription mechanism for event-driven architecture. Great for decoupling.

**Files:** `production-optimizations.md`, `redis.js`, `postgres.js`, `requestLogger.middleware.js`, `admin.controller.js`NaN more)

### Higher-Order Component
Functions that take a component and return an enhanced component.

**Files:** `redis.js`

## Anti-Patterns

### God Object
Files with too many responsibilities (15+ functions). Consider splitting into smaller modules.

**Affected files:** `enhancedAuth.middleware.js`, `mfa.service.js`, `secure-logger.js`, `api-abuse.service.js`, `otp.security.js`

### Long File
Files over 500 lines are harder to maintain. Consider breaking into smaller modules.

**Affected files:** `admin.controller.js`, `auth.controller.js`, `payments.controller.js`, `api-abuse.service.js`, `security-routes.js`

### VBA God Module
VBA modules with 20+ procedures. Consider splitting into smaller modules.

**Affected files:** `otp.security.js`

## Architecture Issues

### 6 Large Files
Files with 15+ functions

**Affected:** `enhancedAuth.middleware.js (16 fns)`, `mfa.service.js (17 fns)`, `secure-logger.js (18 fns)`, `api-abuse.service.js (17 fns)`, `otp.security.js (32 fns)`

### 6 Highly Coupled
Files imported by 8+ others

**Affected:** `production-optimizations.md (12 imports)`, `orders.controller.js (12 imports)`, `otp.security.js (12 imports)`, `auth.controller.js (10 imports)`, `delivery.controller.js (9 imports)`

### 2 Similar Code Blocks
Copy-paste code detected

**Affected:** `get, getAll, reload, del, securityHeaders, generateOtpCode, asyncMiddleware, sha256, asyncMiddleware, generateChecksum, createLogEntry, hasSuspiciousIPPattern, addAllowedMimeType, removeAllowedMimeType, monitorSecurityEvents, addSensitiveKeyPattern, removeSensitiveKeyPattern, isSessionValid, getEligiblePartners, emitToRole, emitToAll, decodeToken, invalidateUserTokens, formatFreshnessDate, generateSessionToken, generateApiKey`, `getItem, setItem, removeItem, phone, otp, updateSessionActivity, jsonRateLimitHandler, isMFAEnabled, getRemainingBackupCodes, getUserMFA, gracefulShutdown, getFileSecurityStats, setMaxFileSize, emitToUser, ok, created, fail, verifyHash, verifyApiKey`

### 8 Architecture Violations
Lower layers importing from higher layers

**Affected:** `config → data`, `utils → services`, `utils → services`, `modules → services`, `config → services`

### 32 High Complexity Files
Files with complexity score >30

**Affected:** `admin.controller.js (249)`, `payments.controller.js (100)`, `auth.controller.js (95)`, `products.controller.js (86)`, `api-abuse.service.js (82)`

## File Details

| File | Folder | Layer | Lines | Functions |
|------|--------|-------|-------|----------|
| `phonepe-payment-integration.md` | docs | note | 302 | 0 |
| `phonepe-security-fixes.md` | docs | note | 289 | 0 |
| `production-optimizations.md` | docs | note | 375 | 0 |
| `webhook-security-fixes.md` | docs | note | 392 | 0 |
| `configLoader.js` | src/config/secrets | config | 187 | 5 |
| `index.js` | src/config/secrets | config | 19 | 2 |
| `secretManager.js` | src/config/secrets | config | 154 | 5 |
| `security.js` | src/config | config | 95 | 9 |
| `index.js` | src/config | config | 62 | 0 |
| `redis.js` | src/db | utils | 161 | 10 |
| `ensureSchema.js` | src/db | utils | 159 | 1 |
| `schema.sql` | src/db | data | 198 | 0 |
| `postgres.js` | src/db | utils | 68 | 4 |
| `enhancedRateLimit.js` | src/middlewares | services | 86 | 6 |
| `error.middleware.js` | src/middlewares | services | 34 | 1 |
| `rbac.middleware.js` | src/middlewares | services | 20 | 1 |
| `auth.middleware.js` | src/middlewares | services | 155 | 0 |
| `enhancedAuth.middleware.js` | src/middlewares | services | 484 | 16 |
| `verifyOtpRateLimiter.js` | src/middlewares | services | 38 | 1 |
| `requestLogger.middleware.js` | src/middlewares | services | 29 | 1 |
| `rateLimiter.js` | src/middlewares | services | 57 | 2 |
| `validate.middleware.js` | src/middlewares | services | 30 | 1 |
| `addresses.controller.js` | src/modules/addresses | modules | 87 | 0 |
| `addresses.routes.js` | src/modules/addresses | modules | 18 | 0 |
| `addresses.validation.js` | src/modules/addresses | modules | 35 | 0 |
| `admin.controller.js` | src/modules/admin | modules | 1007 | 0 |
| `admin.routes.js` | src/modules/admin | modules | 83 | 0 |
| `admin.validation.js` | src/modules/admin | modules | 144 | 0 |
| `auth.controller.js` | src/modules/auth | modules | 532 | 6 |
| `auth.routes.js` | src/modules/auth | modules | 27 | 1 |
| `auth.service.js` | src/modules/auth | modules | 51 | 3 |
| `auth.validation.js` | src/modules/auth | modules | 55 | 1 |
| `enhanced-auth.routes.js` | src/modules/auth | modules | 75 | 1 |
| `mfa.routes.js` | src/modules/auth | modules | 450 | 1 |
| `mfa.service.js` | src/modules/auth | modules | 387 | 17 |
| `banners.controller.js` | src/modules/banners | modules | 46 | 0 |
| `banners.routes.js` | src/modules/banners | modules | 18 | 0 |
| `banners.validation.js` | src/modules/banners | modules | 41 | 0 |
| `cart.routes.js` | src/modules/cart | modules | 33 | 0 |
| `cart.controller.js` | src/modules/cart | modules | 186 | 2 |
| `cart.service.js` | src/modules/cart | modules | 26 | 4 |
| `cart.validation.js` | src/modules/cart | modules | 52 | 0 |
| `catalog.routes.js` | src/modules/catalog | modules | 13 | 0 |
| `catalog.controller.js` | src/modules/catalog | modules | 88 | 0 |
| `catalog.validation.js` | src/modules/catalog | modules | 25 | 0 |
| `categories.routes.js` | src/modules/categories | modules | 31 | 0 |
| `categories.controller.js` | src/modules/categories | modules | 75 | 0 |
| `categories.validation.js` | src/modules/categories | modules | 50 | 0 |
| `coupons.controller.js` | src/modules/coupons | modules | 82 | 1 |
| `coupons.routes.js` | src/modules/coupons | modules | 18 | 0 |
| `coupons.validation.js` | src/modules/coupons | modules | 45 | 0 |
| `delivery.routes.js` | src/modules/delivery | modules | 69 | 0 |
| `delivery.validation.js` | src/modules/delivery | modules | 95 | 0 |
| `slots.controller.js` | src/modules/delivery | modules | 269 | 1 |
| `delivery.controller.js` | src/modules/delivery | modules | 493 | 3 |
| `firebase.routes.js` | src/modules/firebase | modules | 19 | 0 |
| `firebase.controller.js` | src/modules/firebase | modules | 118 | 0 |
| `orders.controller.js` | src/modules/orders | modules | 491 | 1 |
| `orders.validation.js` | src/modules/orders | modules | 77 | 0 |
| `orders.routes.js` | src/modules/orders | modules | 45 | 0 |
| `payments.routes.js` | src/modules/payments | modules | 61 | 2 |
| `payments.controller.js` | src/modules/payments | modules | 722 | 5 |
| `payments.validation.js` | src/modules/payments | modules | 23 | 0 |
| `secure-logger.js` | src/modules/payments | modules | 256 | 18 |
| `phonepe.service.js` | src/modules/payments | modules | 310 | 7 |
| `production-logger.js` | src/modules/payments | modules | 157 | 6 |
| `products.controller.js` | src/modules/products | modules | 337 | 3 |
| `products.routes.js` | src/modules/products | modules | 55 | 0 |
| `products.validation.js` | src/modules/products | modules | 89 | 0 |
| `settings.controller.js` | src/modules/settings | config | 340 | 3 |
| `settings.routes.js` | src/modules/settings | config | 16 | 0 |
| `settings.validation.js` | src/modules/settings | config | 37 | 0 |
| `store.routes.js` | src/modules/settings | data | 16 | 0 |
| `users.routes.js` | src/modules/users | modules | 17 | 0 |
| `metrics.js` | src/routes | utils | 328 | 1 |
| `health.js` | src/routes | utils | 347 | 2 |
| `account-lockout.service.js` | src/security | utils | 436 | 11 |
| `api-abuse.service.js` | src/security | utils | 695 | 17 |
| `csp.service.js` | src/security | utils | 118 | 5 |
| `csrf.service.js` | src/security | utils | 120 | 5 |
| `index.js` | src/security | utils | 341 | 7 |
| `file.security.js` | src/security | utils | 380 | 11 |
| `otp.security.js` | src/security | utils | 463 | 32 |
| `payment.security.js` | src/security | utils | 384 | 9 |
| `redis.security.js` | src/security | utils | 350 | 15 |
| `jwt.security.js` | src/security | utils | 449 | 12 |
| `security-routes.js` | src/security | utils | 515 | 0 |
| `security.middleware.js` | src/security | utils | 389 | 8 |
| `session.service.js` | src/security | utils | 284 | 10 |
| `socket.security.js` | src/security | utils | 459 | 11 |
| `device.service.js` | src/security | utils | 249 | 8 |
| `assignment.service.js` | src/services | services | 182 | 6 |
| `socket.js` | src/socket | utils | 125 | 6 |
| `distance.util.js` | src/utils | utils | 62 | 3 |
| `address.js` | src/utils | utils | 11 | 1 |
| `jwt.js` | src/utils | utils | 445 | 20 |
| `freshness.util.js` | src/utils | utils | 102 | 5 |
| `elasticsearchLogger.js` | src/utils | utils | 280 | 6 |
| `logger.js` | src/utils | utils | 41 | 0 |
| `response.js` | src/utils | utils | 11 | 3 |

*...and 15 more files*
