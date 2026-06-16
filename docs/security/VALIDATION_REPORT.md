# Input Validation Report

**Date:** 2026-06-12

## Validation Framework

- **Primary:** Zod schemas via `validate.middleware.js`
- **Secondary:** Joi in some legacy paths
- **Manual:** Controllers with inline checks

## Well-Validated Modules ✅

| Module | Coverage |
|--------|----------|
| Auth (OTP, refresh) | Zod — `auth.validation.js` |
| Admin CRUD | Zod — `admin.validation.js` |
| Cart, addresses, orders (core) | Zod |
| Payments (initiate/verify) | Zod |
| Delivery (mutations) | Zod — `delivery.validation.js` |
| Catalog, banners, categories | Zod |

## Fixes Applied

| Route/Field | Fix |
|-------------|-----|
| MFA verify/disable token | Added `verifyMfaSchema`, `disableMfaSchema` |
| OTP length | Minimum 6 digits enforced |
| Phone (E.164) | Existing regex validation maintained |
| `addressId` on order create | Ownership + numeric validation added |

## Routes Still Lacking Dedicated Schemas

| Route | Risk | Priority |
|-------|------|----------|
| `GET /api/delivery/route/optimize` | `riderId` unvalidated | Medium |
| `GET /api/products/:id` | Manual `Number()` only | Low |
| `POST /api/store/check-delivery` | Manual type check | Low |
| `GET /api/delivery/slots` | No query schema | Low |
| Enhanced order transitions | State middleware only | Low |

## Rejection Rules Enforced

- Null/empty refresh tokens → Zod `min(1)` ✅
- Invalid phone → E.164 regex ✅
- Invalid OTP → digit count regex ✅
- Oversized payloads → `express.json({ limit: '1mb' })` ✅
- Invalid `addressId` → numeric + ownership ✅

## Recommendations (Not Auto-Fixed)

1. Add Zod query schemas for delivery optimize routes
2. Add `idParamSchema` for all `:id` route params
3. Apply `validate()` to product GET alias routes
