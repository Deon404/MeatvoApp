# Meatvo — Deployment Readiness Report

**Date:** 2026-06-16  
**Target:** Hostinger KVM 1 (Ubuntu 24.04, 1 vCPU / 4 GB RAM)  
**Verdict:** **CONDITIONAL PASS** — code hardened; operator actions required before public launch.

---

## Phase 1 — Security Hardening

### 1.1 Secrets audit

| Item | Status |
|------|--------|
| `docs/production/FINAL_DEPLOYMENT_REPORT.md` | Already uses `<SET_VIA_ENV>` placeholders + rotation note |
| `docs/production/VPS_5_DAY_PLAN.md` | Uses `openssl rand` — no literal passwords |
| Dev-default strings in **source** | **None** — `validateEnv.js` rejects all known dev defaults at startup |
| `docker-compose.yml` | No hardcoded `123400` / `786404` / dev JWT secrets |
| `.gitignore` | `.env` ignored; `docs/security/backups/` ignored |
| Flutter asset bundle | **No `.env`** — `pubspec.yaml` bundles only `assets/env.defaults` + `assets/env.local` (not secrets) |

**Files still containing literal dev secrets (documentation/report only — rotate if ever used in prod):**

| File | Notes |
|------|-------|
| `codeflow-report.md` | Static scan report quoting old vulnerable snippets — **not executed** |
| `backend/src/config/validateEnv.js` | `KNOWN_DEV_SECRETS` blocklist (intentional) |

**Manual action required (confirm before delete):**

- `docs/security/backups/20260612_220957/` — stale controller copies
- `docs/security/backups/remaining-fixes-20260612_221748/` — stale controller copies

### 1.2 SQL injection audit — all FALSE POSITIVE

| File | Reason |
|------|--------|
| `admin.controller.js` | All `$1…$N`; dynamic SQL uses allowlisted column names only |
| `auth.controller.js` | Parameterized queries only |
| `delivery.controller.js` | Fixed SQL fragments + bound params |
| `orders.controller.js` | `nextParam()` placeholder indexing |
| `payments.controller.js` | Parameterized; admin/customer branch is fixed fragment |
| `assignment.service.js` | All `$1…$N` |
| `eta.service.js` | All `$1…$N` |
| `tracking.service.js` | All `$1…$N` |
| `orderLifecycle.service.js` | All `$1…$N` |
| `earnings.service.js` | Date filter from enum switch, not user input |
| `jwt.js` | All `$1` |
| `create_partitions.sh` | CLI arg regex-gated before DDL interpolation |
| `docs/admin.json` | Documentation only |
| `docs/TECHNICAL_REQUIREMENTS_DOCUMENT.md` | Illustrative examples (includes anti-pattern note) |

**Real SQLi fixes:** 0 required.

### 1.3 XSS in admin panel

| Finding | Action |
|---------|--------|
| `backend/admin/admin.html` | **Not present in repo** — backend serves placeholder HTML |
| Production admin UI | **Flutter** `frontend/lib/screens/admin/*` — no `onclick="${...}"` pattern |
| `docs/admin.json` | Scan artifact of old web SPA — not deployed |

**XSS fix applied:** N/A for live code path. If web `admin.html` is restored, use `data-*` + `addEventListener` (pattern documented in security audit).

### 1.4 Shell / Function constructor — FALSE POSITIVE

Spot-checked `phone_screen.dart`, `otp_screen.dart`, `meatvo_layout.dart`, `product_card.dart`:

- No `Process.run()` with unvalidated input
- `dart:io` usage limited to platform checks / file upload paths
- Flags are Flutter closures (`itemBuilder`, `showModalBottomSheet`, socket callbacks)

### 1.5 Firebase API key

`frontend/lib/firebase_options.dart` contains client API key (expected for Firebase SDK).

**Manual (Sadiq — Google Cloud Console):**

1. APIs & Services → Credentials → Firebase API key
2. Application restrictions: Android package + SHA-1, iOS bundle ID
3. API restrictions: limit to Firebase/FCM/Maps APIs actually used

Cannot be enforced via code.

### 1.6 Production hygiene

| Item | Status |
|------|--------|
| `backend/scripts/dev-only/*` | Dev test scripts moved; excluded via `.dockerignore` |
| `backend/test-*.js` at root | None remaining |
| `migrate_order_statuses.js` | Uses `logger`, not `console.log` |
| `production-check.js` / `customer-flow-smoke.js` | Intentional CLI stdout (not debug noise) |
| TODO/FIXME in listed files | **None found** — prior fixes or removed |

### Phase 1 test results

| Script | Result |
|--------|--------|
| `npm run production:check` | **PASS** (dev NODE_ENV; warnings only) |
| `npm run smoke:customer` | **FAIL** — serviceability: test address outside Bokaro 5 km zone (env/data, not regression) |

---

## Phase 2 — Four-Role Order Lifecycle

### 005_add_staff_role.sql

```sql
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'staff';
```

Staff is an **enum value on `user_role`** — no separate permissions table. Routes gated via `rbac(ROLES.STAFF)` on `/api/staff/*` and `enhancedOrders.routes.js` packing endpoints.

### Canonical state mapping (spec ↔ code)

| Spec state | Code enum | Display label |
|------------|-----------|---------------|
| PLACED | `PLACED` | Order Placed |
| CONFIRMED | `CONFIRMED` | Order Confirmed |
| PREPARING | `PACKING_STARTED` | Preparing Your Order |
| READY_FOR_PICKUP | `PACKED` | Ready for Pickup |
| ASSIGNED | `RIDER_ASSIGNED` | Delivery Partner Assigned |
| PICKED_UP | `PICKED_UP` / `RIDER_ACCEPTED` | Legacy alias → OUT_FOR_DELIVERY |
| OUT_FOR_DELIVERY | `OUT_FOR_DELIVERY` | Out for Delivery |
| DELIVERED | `DELIVERED` | Delivered |
| FAILED_DELIVERY | `FAILED_DELIVERY` | **Added in migration 006** |
| CANCELLED | `CANCELLED` | Cancelled |

**Extra states in code (payment/rider sub-states):** `PAYMENT_PENDING`, `PAYMENT_VERIFIED`, `RIDER_REJECTED`, `RIDER_NEARBY`, `REFUNDED` — used internally; mapped for old clients via `lifecycleCompatibility.js`.

### Fixes applied this phase

| Fix | File(s) |
|-----|---------|
| Staff can trigger `CONFIRMED` + `CANCELLED` | `enhancedOrderStateMachine.js` |
| Online payment guard before post-CONFIRMED transitions | `orderLifecycle.service.js` |
| PhonePe `PAYMENT_FAILED` → auto-cancel | `payments.controller.js`, `phonepe.controller.js` |
| Stale payment reconciliation (15 min default, 5 min poll) | `payment-reconciliation.service.js`, `index.js` |
| COD `payment_status = COLLECTED` on DELIVERED | `delivery.controller.js`, migration `006_*` |
| Canonical socket rooms + legacy aliases | `socket.js`, `orderSocketEmit.js`, `orderLifecycle.service.js` |
| Rider COD cash confirmation dialog | `rider_order_detail_screen.dart` |
| `assignment.service` ↔ `order-batcher` cycle | **No cycle** — one-way import only |

### Socket room matrix (post-fix)

| Transition event | Rooms emitted |
|------------------|---------------|
| Any lifecycle change | `order:{orderId}`, `customer_{id}`, `admin:orders`, `admin_room`, `staff:orders`, `staff_room`, `rider:{id}`, `delivery_{id}` |
| Payment failed cancel | Same + reason `payment_failed` |
| Rider assigned | `user:{riderId}`, `delivery_{riderId}`, `rider:{riderId}` |
| Location / ETA | `customer_{id}`, `order:{orderId}` via `tracking.service.js` |

### RBAC — Staff boundary

| Staff CAN | Staff CANNOT |
|-----------|--------------|
| List kitchen orders (`/api/staff/orders`) | Admin settings, pricing, users, coupons |
| Start packing / mark packed (`enhancedOrders`) | Product CRUD, banner management |
| View any order (middleware) | Override payment without `adminOverride` flag |
| Cancel pre-pickup (with reason via transition API) | Confirm orders with PENDING/FAILED online payment |

Admin routes remain `rbac(ROLES.ADMIN)` only.

### Deferred (product decision)

- Staff "confirm PLACED order" queue — COD currently auto-confirms at checkout; ONLINE confirms via PhonePe webhook
- Full rename of enum values to spec names (`PREPARING` vs `PACKING_STARTED`) — display mapping sufficient for launch
- FCM server-side push at every transition — partial implementation remains

---

## Phase 3 — Customer UX/UI

| Item | Status |
|------|--------|
| Live tracking: map + stepper + ETA + rider card | **Verified** in `order_detail_screen.dart` |
| Socket reconnect banner + 30s REST fallback | **Implemented** (`order_tracking_subscription.dart`) |
| `join_order_room` canonical room | **Implemented** (socket service + backend) |
| Rider COD "Collect Cash" confirmation | **Implemented** |
| Cart coupon inline feedback | Existing — verify manually |
| Delivery zone at map-pick step | Partial — backend check exists; UI badge deferred |
| Product card circular dependency | Adapter pattern — no mutual import found |
| Disabled categories "Coming Soon" | Verify in `home` category chips |
| Wishlist empty state | Placeholder remains |
| OTP auto-read / resend timer | `sms_autofill` present — device-dependent |

---

## Remaining Open Items

| ID | Severity | Item | Owner |
|----|----------|------|-------|
| R-01 | **CRITICAL** | VPS not deployed | DevOps |
| R-02 | **CRITICAL** | Run migrations 001→006 in order on prod DB | DevOps |
| R-03 | **CRITICAL** | Rotate all secrets; never use dev defaults | Security |
| R-04 | **CRITICAL** | Firebase API key restrictions in GCP | Sadiq |
| R-05 | **HIGH** | Delete `docs/security/backups/**` after confirmation | Sadiq |
| R-06 | **HIGH** | PhonePe production webhook end-to-end test | Backend |
| R-07 | **HIGH** | MSG91 DLT template approval | Backend |
| R-08 | **HIGH** | Flutter release keystore + production API URL | Mobile |
| R-09 | **MEDIUM** | FCM server push completion | Backend |
| R-10 | **MEDIUM** | Web admin SPA XSS hardening if bundle restored | Frontend |
| R-11 | **LOW** | Wishlist / notifications placeholders | Product |
| R-12 | **LOW** | Dual design palettes (`AppColors` vs `MeatvoColors`) | Design |

---

## Pre-Deploy Checklist — Hostinger KVM 1

### 1. Environment variables (set in `backend/.env` on VPS)

```bash
# Generate each with: openssl rand -hex 32
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
OTP_HASH_SECRET=
MFA_ENCRYPTION_KEY=
UPLOAD_SIGNING_SECRET=

# From VPS Phase 1 setup
DATABASE_URL=postgres://meatvo_user:PASSWORD@127.0.0.1:5432/meatvo_db
REDIS_URL=redis://:PASSWORD@127.0.0.1:6379

# Integrations (production keys)
MSG91_AUTH_KEY=
MSG91_OTP_TEMPLATE_ID=
MSG91_SENDER_ID=
PHONEPE_MERCHANT_ID=
PHONEPE_SALT_KEY=
PHONEPE_SALT_INDEX=1
PHONEPE_ENVIRONMENT=PRODUCTION
PHONEPE_REDIRECT_URL=https://yourdomain.com/payment/return
PHONEPE_WEBHOOK_URL=https://yourdomain.com/api/payments/phonepe/webhook

SENTRY_DSN=
CORS_ORIGINS=https://yourdomain.com
GOOGLE_MAPS_API_KEY=
FIREBASE_API_KEY=
FIREBASE_VAPID_KEY=

# Hardening (must be false/unset)
DEV_AUTH_BYPASS_ENABLED=false
OTP_LOG_TO_CONSOLE=false
DISABLE_API_RATE_LIMIT=false
REDIS_ALLOW_FALLBACK=false

# Optional tuning
PAYMENT_RECONCILE_TIMEOUT_MINUTES=15
PAYMENT_RECONCILE_INTERVAL_MS=300000
PM2_INSTANCES=1
```

### 2. Database migrations (run in order)

```bash
# On VPS after PostgreSQL is up:
psql -U meatvo_user -d meatvo_db -f backend/migrations/004_add_delivery_slots.sql
psql -U meatvo_user -d meatvo_db -f backend/migrations/005_add_staff_role.sql
psql -U meatvo_user -d meatvo_db -f backend/src/db/migrations/006_payment_collected_failed_delivery.sql
node backend/src/db/migrations/migrate_order_statuses.js   # idempotent enum sync
```

`ensureSchema.js` also runs on boot — but run numbered SQL files explicitly on first deploy.

### 3. Docker / PM2 build steps

```bash
# Pack from dev machine
powershell scripts/vps-pack-deploy.ps1
scp meatvo-deploy.tar.gz root@VPS:/opt/meatvo/

# On VPS
cd /opt/meatvo
tar -xzf meatvo-deploy.tar.gz
cp backend/.env.vps.example backend/.env && nano backend/.env
bash scripts/vps-phase2-deploy.sh

# Validate
NODE_ENV=production npm run production:check
npm run smoke
curl -s https://yourdomain.com/health/live
```

### 4. SSL + Nginx

```bash
MEATVO_DOMAIN=yourdomain.com MEATVO_API_DOMAIN=api.yourdomain.com bash scripts/setup-ssl.sh
pm2 restart meatvo-backend --env production
```

### 5. Manual console steps (cannot be done via code)

- [ ] Firebase: API key restrictions (Android SHA-1, iOS bundle)
- [ ] Google Maps: restrict key to server IP + app package
- [ ] PhonePe dashboard: production webhook URL + test ₹1 payment
- [ ] MSG91: live template + sender ID approved
- [ ] Hostinger DNS A records → VPS IP
- [ ] Daily `pg_dump` cron + backup retention
- [ ] External uptime monitor + Sentry alerts
- [ ] Delete `docs/security/backups/**` from git after confirming no longer needed

### 6. Flutter release build

```bash
cd frontend
# Set production API in assets/env.local (not committed) or --dart-define
flutter build appbundle --dart-define=API_BASE_URL=https://api.yourdomain.com
```

---

## Confirmed Fixes Summary (this audit)

- Secrets fail-fast at startup; no dev-default fallbacks in source
- PhonePe failure auto-cancels orders + socket notify
- Payment reconciliation job for stale PENDING payments
- COD cash collection sets `payment_status = COLLECTED`
- Canonical socket rooms (`order:`, `staff:orders`, `admin:orders`, `rider:`) + legacy aliases
- Staff RBAC on packing transitions; payment guard for online orders
- Customer tracking: 30s poll fallback + reconnecting banner
- Rider COD confirmation step before DELIVERED
- Migration 006 for `FAILED_DELIVERY` + `COLLECTED` payment status

---

*Generated by pre-deploy audit — 2026-06-16.*
