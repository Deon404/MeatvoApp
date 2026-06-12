# API Report

**Base**: `{BACKEND_ROOT}/api` (default port 8080)

## Auth

| Method | Path | Auth | Rate Limit |
|--------|------|------|------------|
| POST | `/auth/send-otp` | Public | 10/phone/10min |
| POST | `/auth/verify-otp` | Public | 5/min/phone |
| POST | `/auth/refresh-token` | Public | — |
| POST | `/auth/logout` | JWT+blacklist | — |
| GET | `/auth/me` | JWT+blacklist | — |

## Core (authenticated)

| Group | Prefix | Auth |
|-------|--------|------|
| Cart | `/cart` | JWT |
| Orders | `/orders` | JWT (+ ownership on status update) |
| Addresses | `/addresses` | JWT customer/delivery |
| Payments | `/payments` | JWT (+ public webhook) |
| Delivery | `/delivery` | Mixed |
| Admin | `/admin` | JWT admin |

## Public

| Path | Purpose |
|------|---------|
| `/catalog/*` | Products, categories |
| `/store/status` | Store open/closed |
| `/store/check-delivery` | Serviceability |
| `/delivery/slots` | Available slots |
| `/payments/phonepe/webhook` | PhonePe callback (X-VERIFY) |

## Response Format

```json
{ "ok": true, "success": true, "data": {}, "message": "..." }
```

Errors: `{ "ok": false, "error": { "message": "...", "code": "..." } }`

## Global Rate Limits

- API: 300 req / 15 min
- Auth IP: 60 req / 15 min
- Payments: 10/min per user
- Webhook: 10/min per IP

## Security Fixes

- Order status update now checks customer ownership
- All `protect` routes check Redis token blacklist
