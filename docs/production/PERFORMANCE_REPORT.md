# Performance Report — Meatvo Backend

**Date:** 2026-06-12

---

## Summary

| Metric | Score | Notes |
|--------|-------|-------|
| Query parameterization | Good | All queries use `$n` placeholders |
| Connection pooling | Good | pg pool max=10 (configurable via `PG_POOL_MAX`) |
| Caching | Good | Redis for cart, product cache in controllers |
| N+1 queries | Medium risk | Order list fetches items in loop — acceptable at current scale |
| Payload sizes | Good | JSON limit 1MB |
| Blocking operations | Low risk | SMS/payment are async; no sync crypto on hot path |

**Performance Score:** 72/100

---

## Slow Query Risks

| Query Pattern | Location | Recommendation |
|---------------|----------|----------------|
| Admin order list with JOINs | `orders.controller.js` | Add composite index `(customer_id, status, created_at DESC)` |
| Rider available orders | `delivery.controller.js` | Index on `order_assignments(delivery_partner_id, status)` |
| Product search ILIKE | `products.controller.js` | Consider pg_trgm if search volume grows |

---

## N+1 Patterns

- `getOrders` / admin list: fetches order items per order in a loop. At <10K orders/day this is acceptable. Batch with `WHERE order_id = ANY($1)` if scaling.
- Socket room broadcasts: single emit per event — no N+1.

---

## Large Payloads

- `express.json({ limit: '1mb' })` — appropriate
- Image uploads capped at 5MB (`MAX_FILE_SIZE`)
- Order address stored as JSONB — typically <2KB

---

## Memory

- PM2 `max_memory_restart: 512M` configured
- In-memory Maps for rider location and notifications — lost on restart; Redis migration recommended at scale
- Redis memory fallback in dev only; production requires `REDIS_URL`

---

## Blocking Operations

- PhonePe HTTP calls: async with timeout
- MSG91 SMS: async with retry
- `ensureSchema` on boot: runs once; idempotent ALTERs are fast

---

## Optimizations Applied (Safe)

1. Redis connection with lazy connect
2. Product list caching in Redis (TTL-based)
3. PM2 memory limit + graceful shutdown (15s) to release pool connections
4. Nginx gzip for JSON/static assets
5. `keepalive` upstream in Nginx config

---

## Recommended (Future)

1. Add `(customer_id, created_at DESC)` index on orders
2. Move rider location cache to Redis
3. Run `VACUUM ANALYZE` monthly on VPS
4. Load test with k6: target p95 < 500ms at 100 concurrent users
5. Enable `PM2_INSTANCES=2` on multi-core VPS after Socket.io sticky session setup

---

## Load Testing

Not yet executed. Suggested script:

```bash
k6 run --vus 100 --duration 5m scripts/load-test.js
```

Baseline expectation: health + catalog endpoints < 200ms p95 on 2-vCPU VPS.
