# Meatvo Business Rules Configuration

**Module:** `backend/src/config/businessRules.js`  
**Authority:** Store defaults previously in `storeSettings.util.js`; delivery service radius standardized to **8 km**.

All operational thresholds for dispatch, batching, assignment, ETA, store serviceability, pricing fallbacks, and weight policy are defined in one place. Services must import from `businessRules.js` — do not duplicate magic numbers.

---

## Environment overrides

| Variable | Default | Affects |
|----------|---------|---------|
| `STORE_SETTINGS_CACHE_TTL_MS` | `60000` | Merged store settings cache TTL |
| `BATCH_WAIT_MS` | `180000` (3 min) | Batch assignment wait window |
| `ASSIGNMENT_TIMEOUT_MS` | `10000` (10 s) | Rider accept popup timeout |
| `SMALL_FLEET_THRESHOLD` | `3` | Online riders at or below this → direct assign |

No other rules are env-overridable in Phase 1.

---

## Store & serviceability (`STORE`)

| Rule | Value | Used by |
|------|-------|---------|
| `deliveryRadiusKm` | **8.0 km** | Serviceability, pricing zone, assignment tier 3, schema DDL |
| `centerLat` / `centerLng` | 23.6583 / 86.1764 | Store center, distance checks |
| `minOrderAmount` | ₹150 | Checkout / store settings |
| `deliveryFee` | ₹30 | Checkout delivery charge |
| `freeDeliveryAbove` | ₹500 | Free delivery threshold |
| `storeOpenTime` / `storeCloseTime` | 09:00 / 22:00 IST | Store hours |
| `cacheTtlMs` | 60 s | `getMergedStoreSettings` cache |
| `dbReadTimeoutMs` | 5 s | Store settings DB reads |
| `minDeliveryRadiusKm` / `maxDeliveryRadiusKm` | 0.5 / 100 | Admin zone validation |

---

## Assignment (`ASSIGNMENT`)

| Rule | Value | Notes |
|------|-------|-------|
| `maxAttempts` | 3 | Auto-assign retries before admin alert |
| `attemptTtlSeconds` | 86400 (24 h) | Redis attempt counter TTL |
| `timeoutMs` | 10 s | Rider accept window |
| `smallFleetThreshold` | 3 | ≤3 online riders → skip broadcast |
| `distanceTiersKm` | 3, 5, **8** | Nearby → medium → extended (8 = service radius) |
| `defaultPartnerSearchRadiusKm` | 5 | Default `getEligiblePartners` param |
| Scoring weights | 35% / 25% / 20% / 10% / 10% | Distance / acceptance / load / rating / zone |
| `distancePenaltyPerKm` | 15 | Score decreases per km |
| `loadPenaltyPerActiveOrder` | 25 | Per active delivery |
| `zoneFamiliarityDeliveryCap` | 10 | Max deliveries counted for zone score |
| `defaultRatingOutOf5` | 4.0 | When rider has no ratings |
| `fallbackDistanceKm` | 2 | Missing GPS distance fallback |

Assignable order status: `PACKED` only (`assignment.constants.js`).

**Rider accept guard:** Riders may accept only `PACKED` orders with `weight_reconciliation_status` of `COMPLETED` or `NOT_REQUIRED`. `CONFIRMED` and pending-reconciliation orders are rejected (`delivery.controller.js`, `assignment.service.js` auto-accept).

**Batch reassignment:** Batch inserts use `ON CONFLICT (order_id) DO UPDATE` (same as manual assignment) so `CANCELLED` assignment rows are reused instead of blocking reassignment.

---

## Refunds (`cashfreeRefund.service.js`)

| Path | Trigger | Gateway |
|------|---------|---------|
| Weight partial refund | `packingWeightReconciliation.service` after pack | Cashfree `POST /orders/{id}/refunds` for `ONLINE` only |
| Failed delivery refund | `failedDelivery.service` on admin `REFUND` resolution | Full order refund via same service |

Rules:
- Idempotency key stored on `order_partial_refunds.idempotency_key` (unique index)
- `gateway_refund_id` persisted after submit; retries skip when already set
- COD refunds remain `RECORDED` in DB only (no gateway call)
- Full payment row marked `REFUNDED` only for failed-delivery full refunds

**Weight reconciliation:** Only `packingWeightReconciliation.service` may set `weight_reconciliation_status = COMPLETED`. Startup backfill in `ensureSchema` was removed.

---

## App settings schema

Canonical `app_settings` table (single operational row + `value` JSONB for theme/banner):

| Column | Purpose |
|--------|---------|
| `id` | SERIAL PRIMARY KEY |
| `delivery_charge`, `min_order_amount`, `delivery_radius_km` | Operational pricing |
| `store_open`, `store_acceptance_mode`, `store_open_time`, `store_close_time` | Store hours / acceptance |
| `value` | JSONB key-value (theme, banner, appInfo, free_delivery_above) |
| `updated_at` | Last update |

Used consistently by `ensureSchema`, `appSettings.js`, `settings.controller.js`, `admin.controller.js`, `storeSettings.util.js`. Legacy `key TEXT PRIMARY KEY` shape is not used by application code.

---

## Batching (`BATCHING`)

| Rule | Value | Notes |
|------|-------|-------|
| `radiusKm` | 2.0 km | Order-to-order cluster distance |
| `maxBatchSize` | 4 | Max orders per batch |
| `waitMs` | 3 min | Hold before assign (env override) |
| `edgeZoneSkipKm` | **4.0 km** | `deliveryRadiusKm / 2` — skip wait for far orders |
| `lookbackMinutes` | 10 | Unassigned PACKED order scan window |

---

## ETA — live tracking (`ETA`)

| Rule | Value | Notes |
|------|-------|-------|
| `roadDistanceFactor` | 1.2 | Straight-line → road estimate |
| `bufferMinutes` | 2 | Stops / parking buffer |
| `nearbyThresholdKm` | 0.5 (500 m) | `RIDER_NEARBY` trigger |
| `initialFallbackMinutes` | 30 | Default ETA when address missing |
| `riderSpeedClampMinKmh` / `Max` | 10 / 50 | Historical speed clamp |
| `vehicleSpeedsKmh` | bike 25, scooter 30, … | Per vehicle type |
| `trafficFactors` | Hourly 1.0–1.5× | Rush-hour multipliers |

---

## Tracking (`TRACKING`)

Parallel legacy ETA path in `tracking.service.js` (preserved values).

| Rule | Value |
|------|-------|
| `nearbyThresholdKm` | 0.5 |
| `offlineThresholdMs` | 5 min |
| `positionCacheFreshMs` | 30 s |
| `nearbyNotificationEtaMinutes` | 5 |
| `etaBufferFactor` | 1.2 |
| `minEtaMinutes` | 5 |
| `vehicleSpeedsKmh` | bike 25, scooter 30, bicycle 15, car **35**, default 25 |

---

## Routing (`ROUTING`)

| Rule | Value |
|------|-------|
| `avgSpeedKmh` | 20 |
| `stopMinutes` | 5 per stop |

---

## Weight policy (`WEIGHT`)

| Rule | Value |
|------|-------|
| `toleranceG` | ±50 g before reconciliation action |

---

## Pricing fallbacks (`PRICING`)

| Rule | Value |
|------|-------|
| `defaultDeliveryFee` | ₹30 |
| `freeDeliveryThreshold` | ₹500 |

---

## Conflict resolutions (Phase 1)

| Location | Was | Now |
|----------|-----|-----|
| Admin `delivery_radius_km` fallback | 5 km | **8 km** (`STORE.deliveryRadiusKm`) |
| `store_settings` DDL DEFAULT | 5.0 | **8.0** |
| `distance.util` default radius param | 5 km | **8 km** |
| `ensureSchema` CREATE DEFAULT | 5.0 | **8.0** (seed was already 8.0) |

Runtime behavior unchanged except these documented fallback alignments.

---

## Regression tests

```bash
cd backend && npm run test:unit -- --testPathPatterns=businessRules
cd backend && npm run test:unit -- --testPathPatterns="cashfree-refund|app-settings-schema"
cd backend && npm run test:integration -- --testPathPatterns="batch-reassignment|rider-accept-guard"
```

Tests assert exported values match pre-refactor constants, batch reassignment reuses cancelled rows, rider accept guards, Cashfree refund idempotency, and unified `app_settings` schema.
