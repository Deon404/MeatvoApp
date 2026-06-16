# Authorization Security Report

**Date:** 2026-06-12

## IDOR Audit Results

### Routes Verified Secure ✅

| Route | Ownership Check | File |
|-------|----------------|------|
| `GET /api/orders/:id` | Owner / admin / assigned rider | `orders.controller.js:439-466` |
| `PUT /api/orders/:id/cancel` | `customer_id === req.user.id` | `orders.controller.js:578-591` |
| `PATCH/DELETE /api/addresses/:id` | `user_id = req.user.id` | `addresses.controller.js` |
| `POST /api/payments/initiate` | `customer_id` join | `payments.controller.js` |
| `GET /api/payments/:orderId/status` | `customer_id` scoped | `payments.controller.js:323-335` |
| `GET /api/users/me` | Self only | `users.routes.js` |
| Cart operations | Redis key = `user.id` | `cart.controller.js` |

### Issues Found & Fixed

| Issue | Severity | Fix |
|-------|----------|-----|
| Rider location `orderId` spoofing | HIGH | Assignment check in `tracking.service.js`, `socket.js` |
| `validateOrderOwnership` unknown role bypass | MEDIUM | Deny unrecognized roles in `orderState.middleware.js` |
| Slot release by any delivery user | MEDIUM | Restricted to `rbac(ADMIN)` in `delivery.routes.js` |
| `addressId` on order create without ownership | LOW | Validated in `orders.controller.js` |
| `join_delivery_room` any authenticated user | HIGH | Role gate in `socket.js` |

### Remaining Authorization Gaps

| Issue | Severity | Location | Recommendation |
|-------|----------|----------|----------------|
| `PUT /api/orders/:id/status` middleware-only `protect` | MEDIUM | `orders.routes.js:41` | Split by role or add `validateOrderOwnership` |
| Delivery available orders expose PII | LOW | `delivery.controller.js:93-103` | Redact until assignment (product decision) |
| Public `/uploads` if filename leaked | MEDIUM | `index.js:117` | Signed URLs or auth-gated serve |

## RBAC Summary

- **Admin:** All `/api/admin/*` → `[protect, rbac(ADMIN)]` ✅
- **Delivery:** `rbac(DELIVERY)` on delivery module ✅
- **Customer:** Implicit via ownership checks ✅

## Fixes Applied

1. `tracking.service.js` — `verifyRiderAssignedToOrder()`
2. `socket.js` — delivery room + location order assignment
3. `orderState.middleware.js` — deny unknown roles
4. `delivery.routes.js` — admin-only slot release
5. `orders.controller.js` — addressId ownership validation
