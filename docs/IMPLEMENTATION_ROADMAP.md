# Meatvo — Complete Implementation Roadmap

**Document Owner:** CTO Office  
**Version:** 1.1  
**Date:** June 13, 2026  
**Target Launch:** Q3 2026 — Bokaro Steel City (Pilot)  
**Planning Horizon:** Zero to Production Launch

---

## Executive Summary

Meatvo is a hyperlocal fresh-meat delivery platform targeting 30-minute delivery in urban India. This roadmap defines the end-to-end implementation path from planning through launch across nine phases.

**Technology baseline (actual codebase):**

| Layer | Stack |
|-------|-------|
| Backend | Node.js (Express 5), PostgreSQL, Redis, Socket.io |
| Frontend (all roles) | **Flutter 3.9+ only** (`frontend/`) — Customer, Admin, Rider |
| Auth | JWT + OTP (MSG91), optional MFA |
| Payments | PhonePe (COD + online) |
| Infra | VPS, Nginx, Docker, Cloudflare |

### Frontend Architecture Decision

> **All client-facing UI is Flutter.** There is no web admin, web customer, or web rider app in scope. Role-based routing within the same Flutter codebase (or separate build flavors) serves customers, store admins, and delivery riders. Backend web SPAs under `admin/`, `customer/`, and `delivery/` are **out of scope** and not required for launch.

**Current state:** Core backend APIs and Flutter flows for customer, admin, and rider are substantially built. Remaining work centers on Flutter polish, FCM, wishlist sync, admin order detail UX, payment hardening, QA, and production deployment.

**Estimated total timeline:** 16–22 weeks (parallel workstreams) with a lean team of 7–9 FTEs.  
**Critical path:** Planning → Backend API freeze → Customer app checkout → Payment certification → E2E testing → Production deployment → Launch.

---

## Program Timeline (Gantt Overview)

```
Week:  1-3    4-10   8-16   10-14  12-16  14-17  16-20  18-21  20-24
       ┌────┐
P1     │Plan│
       └────┘
            ┌──────────────┐
P2          │Backend Dev   │────────────────────┐
            └──────────────┘                    │
                 ┌──────────────────────────────┤
P3               │Customer App (Flutter)        │
                 └──────────────────────────────┤
                      ┌─────────────┐            │
P4                    │Flutter Admin│            │
                      └─────────────┘            │
                           ┌──────────────┐      │
P5                         │Rider App     │     │
                           └──────────────┘     │
                                ┌─────────┐     │
P6                              │Payments │     │
                                └─────────┘     │
                                     ┌──────────┴──┐
P7                                   │Testing      │
                                     └─────────────┘
                                          ┌────────┐
P8                                        │Deploy  │
                                          └────────┘
                                               ┌───────┐
P9                                             │Launch │
                                               └───────┘
```

---

## Team Structure (Program-Level)

| Role | Count | Primary Phases |
|------|-------|----------------|
| CTO / Tech Lead | 1 | All (architecture, decisions, sign-off) |
| Product Manager | 1 | P1, P9 |
| Backend Engineer | 2 | P2, P6, P8 |
| Flutter Engineer | 2–3 | P3, P4, P5 |
| DevOps / SRE | 1 | P2, P7, P8 |
| QA Engineer | 1–2 | P7 |
| UI/UX Designer | 1 | P1, P3–P5 |
| Operations Manager | 1 | P1, P9 (rider onboarding, store ops) |

---

## Phase 1: Planning

**Objective:** Align product, engineering, and operations on scope, architecture, and launch criteria before code freeze decisions.

**Estimated Duration:** 2–3 weeks

### Tasks

| # | Task | Owner |
|---|------|-------|
| 1.1 | Finalize MVP scope (Bokaro pilot: 5–10 km radius, ~100 SKUs, COD + PhonePe) | PM |
| 1.2 | Review and sign off PRD, UI/UX spec (`docs/UI_UX_SPECIFICATION.md`) | PM + Design |
| 1.3 | Architecture review: modular monolith (Express), data model, API contracts | CTO + Backend |
| 1.4 | Define API specification (OpenAPI) and env manifest (`shared/env-manifest.json`) | Backend Lead |
| 1.5 | Infrastructure sizing: VPS spec, PostgreSQL/Redis, Cloudflare, backup strategy | DevOps |
| 1.6 | Third-party vendor setup: MSG91, PhonePe merchant sandbox, Google Maps API, FSSAI compliance checklist | Ops + Backend |
| 1.7 | Sprint plan: 2-week sprints, milestone gates, definition of done | PM + CTO |
| 1.8 | Risk register and mitigation plan | CTO |
| 1.9 | Rider recruitment plan, dark-store layout, cold-chain SOPs | Ops |
| 1.10 | Legal: Privacy Policy, Terms of Service, refund policy | Legal / PM |

### Dependencies

- None (program kickoff)
- Business funding and FSSAI registration in progress

### Team Roles

- **Lead:** Product Manager  
- **Contributors:** CTO, UI/UX Designer, Operations Manager, Backend Lead  
- **Stakeholders:** Founder, Legal, Finance

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Scope creep (wishlist, subscriptions, multi-city) | High | Strict MVP boundary document; Phase 2 backlog |
| PhonePe merchant approval delays | High | Start KYC early; COD-only fallback for soft launch |
| Design system split (`AppColors` vs `MeatvoColors`) | Medium | Canonical palette decision in UI spec (Meatvo v2) |
| Underestimated ops readiness | High | Parallel ops track; rider training before P5 |

### Deliverables

- [ ] Signed MVP scope document  
- [ ] Architecture decision record (ADR)  
- [ ] API specification (`docs/API_SPECIFICATION.yaml`)  
- [ ] Sprint backlog (Jira/Linear) with story points  
- [ ] Infrastructure runbook draft  
- [ ] Figma design system + key screen mocks  
- [ ] Go/No-Go criteria for each phase gate  

---

## Phase 2: Backend Development

**Objective:** Deliver a production-grade REST API + WebSocket layer supporting all client apps and payment flows.

**Estimated Duration:** 6–8 weeks (3–4 weeks remaining given current codebase)

### Tasks

| # | Task | Status |
|---|------|--------|
| 2.1 | PostgreSQL schema finalization + migrations (`schema.sql`, partitions) | Partial |
| 2.2 | Auth: OTP send/verify, JWT refresh, MFA (speakeasy), account lockout | Done |
| 2.3 | Users, addresses, serviceability check (`/api/store/check-delivery`) | Done |
| 2.4 | Catalog: products, categories, banners, coupons | Done |
| 2.5 | Redis-backed cart sync | Done |
| 2.6 | Order state machine (place → confirm → prep → out → delivered → cancel) | Done |
| 2.7 | Delivery: express ETA, rider assignment, location updates, proof upload | Done |
| 2.8 | Admin APIs: dashboard, CRUD, settings, rider management | Done |
| 2.9 | Socket.io: order status, rider location, admin notifications | Done |
| 2.10 | Upload security: signed URLs, file validation, delivery proof | Done |
| 2.11 | Rate limiting, CSRF, RBAC, admin IP allowlist | Done |
| 2.12 | Observability: Winston, Sentry, `/health`, `/metrics` | Partial |
| 2.13 | API documentation sync with implementation | Pending |
| 2.14 | Performance: query indexes, connection pooling, Redis cache strategy | Pending |
| 2.15 | Staging environment with seed data | Pending |
| 2.16 | Smart order batching for rider assignment (`order-batcher.js`, 2 km / max 4, 3 min wait window) | Done |

### Dependencies

- Phase 1: API spec, env manifest, vendor accounts  
- Blocks: Phases 3, 4, 5, 6

### Team Roles

- **Lead:** Backend Engineer (Senior)  
- **Contributors:** Backend Engineer, DevOps (infra wiring), QA (API contract tests)  
- **Review:** CTO (security sign-off)

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Order state race conditions under load | High | Transaction locks; idempotency keys on place-order |
| Redis/DB single point of failure | Medium | Daily backups; Redis persistence; failover runbook |
| Socket scaling on single VPS | Medium | Sticky sessions via Nginx; Redis adapter for Socket.io |
| Security regression | High | Security audit checklist (`docs/security/`) before P7 |

### Deliverables

- [ ] Production-ready API on port 8080 (`/api/*`)  
- [ ] Database schema + migration scripts  
- [ ] Postman/OpenAPI collection  
- [ ] Security hardening report (signed)  
- [ ] Staging deployment with automated smoke tests  
- [ ] Backend README + env examples (`.env.example`)  

---

## Phase 3: Frontend Development (Customer App)

**Objective:** Ship the Flutter customer app for iOS and Android covering browse → cart → checkout → track.

**Estimated Duration:** 8–10 weeks (5–6 weeks remaining)

### Tasks

| # | Task | Status |
|---|------|--------|
| 3.1 | App shell: splash, onboarding, location permission | Done |
| 3.2 | Auth flow: phone → OTP → session persistence | Done |
| 3.3 | Home: banners, categories, product carousel, search | Done |
| 3.4 | Catalog + product detail (variants, pricing, add-to-cart) | Done |
| 3.5 | Cart sync with backend (Riverpod + `CartService`) | Done |
| 3.6 | Checkout: address picker, express delivery ETA, coupon, payment method | Done |
| 3.7 | Order list + order detail + live status (Socket.io) | Done |
| 3.8 | Address CRUD with Google Maps picker | Done |
| 3.9 | Profile, account settings, order history | Done |
| 3.10 | Design system — auth, splash, legal, wishlist, cart, checkout, profile on MeatvoTheme | In progress |
| 3.11 | Wishlist (local sync + product fetch) | Done |
| 3.12 | Push notifications (FCM — token sync after login + splash) | Partial |
| 3.13 | Error tracking (Sentry init in `main.dart`) | Done |
| 3.14 | Privacy Policy / ToS screens | Done |
| 3.15 | App store assets: icons, screenshots, descriptions | Pending |
| 3.16 | Performance: image caching, shimmer loaders, offline empty states | Partial |
| 3.17 | Address default UX + checkout/payment polish | Done |
| 3.18 | Live order tracking UX (customer map + rider in-app nav + proof) | Done |

### Dependencies

- Phase 2: Auth, catalog, cart, orders, delivery APIs stable  
- Phase 6: Payment redirect flow for online checkout  
- Phase 1: UI/UX spec and Figma mocks approved

### Team Roles

- **Lead:** Flutter Engineer (Senior)  
- **Contributors:** Flutter Engineer, UI/UX Designer, QA  
- **Integration:** Backend Engineer (API troubleshooting)

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Play Store / App Store review delays | High | Submit 3 weeks before launch; comply with data safety forms |
| Google Maps API quota/cost | Medium | Geocoding cache; restrict API keys by bundle ID |
| Two design palettes causing inconsistent UX | Medium | Migrate screen-by-screen per UI spec directive |
| PhonePe redirect UX on iOS WebView | Medium | Test deep links; fallback to external browser |

### Deliverables

- [ ] Flutter APK + AAB (Android) and IPA (iOS)  
- [ ] Customer app covering full purchase funnel  
- [ ] Loading / empty / error states on all data screens  
- [ ] App Store + Play Store listing drafts  
- [ ] Internal TestFlight / internal testing track builds  

---

## Phase 4: Flutter Admin Application

**Objective:** Enable store operators to manage catalog, orders, riders, and settings from the Flutter admin role — no web dashboard.

**Estimated Duration:** 3–4 weeks (1–2 weeks remaining)

**Existing screens** (`frontend/lib/screens/admin/`): dashboard, orders, orders map, products, categories, banners, users, user detail, riders, settings.

### Tasks

| # | Task | Status |
|---|------|--------|
| 4.1 | Admin auth (phone OTP + admin role JWT, MFA via backend) | Done |
| 4.2 | Dashboard: GMV, orders today, revenue, quick actions | Done |
| 4.3 | Order list: filters, status update, rider assignment | Done |
| 4.4 | Order detail screen (tap from orders list → full timeline) | Done |
| 4.5 | Product CRUD + image upload | Done |
| 4.6 | Category, banner management | Done |
| 4.7 | User and rider management + user detail | Done |
| 4.8 | Store settings: delivery radius, open/close toggle, serviceability | Done |
| 4.9 | Real-time new-order alerts (Socket.io + overlay banner) | Done |
| 4.10 | Orders map view with route optimization | Done |
| 4.11 | Role-based access (3 roles: customer, delivery, admin/store owner) | Done |
| 4.12 | Export: orders summary / share report from app | Pending |
| 4.13 | Tablet-optimized admin layouts (768×1024) | Partial |

### Dependencies

- Phase 2: Admin APIs, upload endpoints, Socket.io  
- Can run parallel with Phase 3 after API freeze (week 4+)

### Team Roles

- **Lead:** Flutter Engineer  
- **Contributors:** Backend Engineer, Operations Manager (UAT)  
- **Design:** UI/UX (tablet admin layouts per `docs/UI_UX_SPECIFICATION.md` §11)

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Admin app not used by ops team | High | Ops UAT on real devices; Hindi UI labels |
| Small phone screen for dense admin data | Medium | Prioritize tablet or large Android phones for store managers |
| Unauthorized admin access | Critical | MFA + backend RBAC; admin role enforced server-side |
| Bulk product upload missing | Medium | In-app multi-image upload; CSV import post-launch |

### Deliverables

- [ ] Flutter admin role production-ready on Android (tablet/phone)  
- [ ] Order detail screen with timeline, items, rider assignment  
- [ ] Ops team training guide (SOP document)  
- [ ] Admin UAT sign-off from Operations Manager  

---

## Phase 5: Rider Application

**Objective:** Equip delivery partners to accept orders, navigate, update status, and capture proof of delivery.

**Estimated Duration:** 4–5 weeks (2–3 weeks remaining)

### Tasks

| # | Task | Status |
|---|------|--------|
| 5.1 | Rider auth (phone OTP, rider role JWT) | Done |
| 5.2 | Dashboard: available / active / completed orders | Done |
| 5.3 | Accept / reject order with timeout | Done |
| 5.4 | Navigation to customer (Google Maps deep link) | Done |
| 5.5 | Status updates: picked up → out for delivery → delivered | Done |
| 5.6 | GPS location broadcast to backend (Socket.io) | Done |
| 5.7 | COD collection confirmation | Done |
| 5.8 | Delivery proof photo upload | Done |
| 5.9 | Rider profile, earnings summary | Partial |
| 5.10 | Background location (Android/iOS permissions) | Pending |
| 5.11 | Offline queue for status updates | Pending |
| 5.12 | Rider onboarding flow + document upload | Pending |
| 5.13 | In-app navigation map + delivery stepper UX | Done |
| 5.14 | Smart order batching: proximity batch + rider alert UI (`orderIds`, accept-all) | Done |

### Dependencies

- Phase 2: Delivery module, location API, proof upload  
- Phase 4: Rider accounts created via admin  
- Operations: Rider fleet recruited and trained

### Team Roles

- **Lead:** Flutter Engineer  
- **Contributors:** Backend Engineer, Operations Manager, QA  
- **Field testing:** 5–10 pilot riders in Bokaro

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Background GPS battery drain | Medium | Configurable update interval; geofence triggers |
| Rider app abandonment | High | Simple 3-tap flow; Hindi language support |
| Fake GPS / location spoofing | Medium | Server-side sanity checks; speed validation |
| Insufficient rider supply at launch | Critical | Recruit 2× expected peak capacity before P9 |

### Deliverables

- [ ] Rider Flutter app (Android priority; iOS if fleet uses iPhones)  
- [ ] Rider training manual (English)  
- [ ] Pilot run: 50+ test deliveries in staging/production  
- [ ] Rider onboarding checklist (KYC, uniform, bag, phone)  

---

## Phase 6: Payment Integration

**Objective:** Secure, PCI-compliant payment flows for COD and PhonePe online payments with reconciliation.

**Estimated Duration:** 2–3 weeks

### Tasks

| # | Task | Status |
|---|------|--------|
| 6.1 | PhonePe merchant account + sandbox credentials | Pending (vendor) |
| 6.2 | Payment initiate API (`/api/payments/initiate`) | Done |
| 6.3 | Payment verify + webhook handler | Done |
| 6.4 | Checksum validation (`phonepeChecksum.js`) | Done |
| 6.5 | COD flow: order placed without prepayment | Done |
| 6.6 | Flutter: redirect to PhonePe + status poller | Done |
| 6.7 | PhonePe native SDK (optional) | Deferred |
| 6.8 | Refund API + admin trigger | Partial |
| 6.9 | Payment reconciliation dashboard | Pending |
| 6.10 | Idempotency on webhook (duplicate event handling) | Done |
| 6.11 | Production PhonePe keys in secrets manager | Pending |
| 6.12 | PCI scope documentation (SAQ-A if redirect-only) | Pending |

### Dependencies

- Phase 2: Orders module, payment controller  
- Phase 3: Checkout UI integration  
- External: PhonePe merchant approval (start in Phase 1)

### Team Roles

- **Lead:** Backend Engineer (Senior)  
- **Contributors:** Flutter Engineer, Finance/Ops (reconciliation), DevOps (secrets)  
- **Compliance:** CTO + Finance

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| PhonePe production approval delayed | Critical | Soft launch COD-only; online payments in week 2 post-launch |
| Webhook delivery failures | High | Retry queue; manual reconcile job; status poll fallback |
| Double-charge on network retry | High | Idempotency keys; server-side payment state machine |
| UPI downtime during peak hours | Medium | Prominent COD option; retry UX |

### Deliverables

- [ ] PhonePe sandbox E2E test report  
- [ ] Production payment credentials secured (AWS SSM / env)  
- [ ] Webhook endpoint registered with PhonePe  
- [ ] Daily reconciliation process documented  
- [ ] Payment security audit (`docs/security/PAYMENT_SECURITY_REPORT.md`) signed  

---

## Phase 7: Testing

**Objective:** Validate functional correctness, security, performance, and operational readiness before production cutover.

**Estimated Duration:** 3–4 weeks

### Tasks

| # | Task | Type |
|---|------|------|
| 7.1 | Test plan + traceability matrix (PRD → test cases) | QA |
| 7.2 | API integration tests (auth, cart, orders, payments) | Automated |
| 7.3 | Customer journey E2E: browse → pay → track → deliver | Manual + Playwright |
| 7.4 | Rider journey E2E: accept → navigate → deliver → proof | Manual |
| 7.5 | Admin journey: create product → receive order → assign rider | Manual |
| 7.6 | Payment test matrix: COD, PhonePe success/fail/timeout/webhook | QA + Finance |
| 7.7 | Security testing: OWASP top 10, auth bypass, rate limits | Security |
| 7.8 | Load test: 500 concurrent users, 200 orders/hour | DevOps |
| 7.9 | Socket.io stress test (100 concurrent tracking sessions) | DevOps |
| 7.10 | Mobile device matrix (Android 10–14, iOS 15–17) | QA |
| 7.11 | Regression suite in CI (GitHub Actions) | DevOps |
| 7.12 | UAT with ops team (3-day simulated launch) | Ops + QA |
| 7.13 | Bug triage: P0/P1 fix before launch; P2+ backlog | All |

### Dependencies

- Phases 2–6 feature-complete on staging  
- Staging environment mirrors production  
- Test data: products, addresses, test riders

### Team Roles

- **Lead:** QA Engineer  
- **Contributors:** All engineers, DevOps, Operations Manager  
- **Sign-off:** CTO (P0/P1 zero open), PM (UAT passed)

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Insufficient test coverage on payment edge cases | Critical | Dedicated payment test sprint; finance sign-off |
| Load test not representative | Medium | Model on Bokaro peak (Friday 6–9 PM) |
| UAT findings too late | High | Start UAT at 80% feature complete, not 100% |
| No automated mobile tests | Medium | Manual device lab; Detox/Maestro in Phase 2 post-launch |

### Deliverables

- [ ] Test plan document with pass/fail criteria  
- [ ] Test execution report (≥95% pass rate on P0/P1)  
- [ ] Load test report (API P95 < 200ms, 0 errors at target load)  
- [ ] Security test report (no critical/high open findings)  
- [ ] UAT sign-off from Operations  
- [ ] Known issues list with launch acceptance  

---

## Phase 8: Deployment

**Objective:** Provision production infrastructure, deploy all services, and validate monitoring and rollback procedures.

**Estimated Duration:** 2 weeks

### Tasks

| # | Task |
|---|------|
| 8.1 | Provision VPS (Mumbai/ap-south-1): 8 vCPU, 16 GB RAM, 200 GB SSD |
| 8.2 | Docker Compose stack: API, PostgreSQL 15, Redis 7 |
| 8.3 | Nginx: SSL (Let's Encrypt), reverse proxy, WebSocket upgrade |
| 8.4 | Cloudflare: DNS, CDN, WAF, DDoS protection |
| 8.5 | Secrets: production env vars, PhonePe keys, MSG91, JWT secrets |
| 8.6 | Database: production schema migrate, seed catalog, admin user |
| 8.7 | Redis: persistence (AOF), memory limits |
| 8.8 | Backups: daily PostgreSQL → Cloudflare R2; restore drill |
| 8.9 | Monitoring: Prometheus + Grafana dashboards |
| 8.10 | Alerting: uptime (UptimeRobot), error rate (Sentry), disk/memory |
| 8.11 | CI/CD: GitHub Actions → staging → production with manual gate |
| 8.12 | Mobile: production API URLs in `.env`, release builds to stores |
| 8.13 | Rollback runbook: previous Docker image, DB migration rollback |
| 8.14 | Production smoke test checklist |

### Dependencies

- Phase 7: All P0/P1 bugs resolved  
- Phase 6: Production payment credentials  
- Domain, SSL, Cloudflare account ready

### Team Roles

- **Lead:** DevOps / SRE  
- **Contributors:** Backend Engineer, CTO  
- **On-call:** DevOps + Backend (launch week rotation)

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Database migration failure on prod | Critical | Test migrate on staging clone; maintenance window |
| Secret leakage in logs/env | Critical | Secret scan in CI; never log payment payloads |
| Single VPS outage | High | Backup VPS standby; 4-hour RTO target |
| App store build pointing to wrong API | High | Env validation script in CI; smoke test post-deploy |

### Deliverables

- [ ] Production environment live at `api.meatvo.com` (or chosen domain)  
- [ ] SSL A+ rating, Cloudflare WAF active  
- [ ] Monitoring dashboards + alert rules configured  
- [ ] Backup + restore verified (RPO < 24h, RTO < 4h)  
- [ ] Deployment runbook + rollback runbook  
- [ ] On-call schedule for launch week  

---

## Phase 9: Launch

**Objective:** Execute controlled go-live in Bokaro Steel City, acquire first customers, and stabilize operations.

**Estimated Duration:** 2–3 weeks (launch week + 2-week stabilization)

### Tasks

| # | Task | Timing |
|---|------|--------|
| 9.1 | Go/No-Go meeting (CTO, PM, Ops, Founder) | T-7 days |
| 9.2 | Soft launch: 50 invited users (friends/family) | T-5 days |
| 9.3 | Rider fleet activation (minimum 8 riders, 2 shifts) | T-3 days |
| 9.4 | Inventory stocking + cold-chain verification | T-2 days |
| 9.5 | Marketing: local social, flyers, referral codes | T-1 day |
| 9.6 | Public launch: app store release, website live | T-0 |
| 9.7 | War room: 12-hour coverage for first 72 hours | T-0 to T+3 |
| 9.8 | Monitor KPIs: orders, delivery time, crash rate, payment success | Daily |
| 9.9 | Customer support channel (WhatsApp + phone) | T-0 |
| 9.10 | Daily standup: ops + engineering for first 2 weeks | T+1 to T+14 |
| 9.11 | Post-launch retrospective | T+14 |
| 9.12 | Phase 2 backlog prioritization (FCM, wishlist, multi-store) | T+14 |

### Dependencies

- Phase 8: Production stable for 48+ hours  
- Phase 7: UAT sign-off  
- Operations: riders trained, store stocked, FSSAI display ready  
- Marketing: launch assets approved

### Team Roles

- **Launch Commander:** Operations Manager  
- **Technical Lead:** CTO (incident response)  
- **Support:** PM (customer comms), all engineers (on-call rotation)  
- **Marketing:** Local campaigns, influencer outreach

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Order surge exceeds rider capacity | High | Queue orders; express ETA queue messaging; surge banner |
| Cold-chain failure / quality complaint | Critical | Temperature logs; immediate refund + replacement SOP |
| Negative app reviews at launch | Medium | Proactive support outreach; fix P0 bugs within 24h |
| Low initial adoption | Medium | Referral incentives; ₹100 off first order |
| Payment gateway outage on launch day | Medium | COD prominently promoted; status page |

### Deliverables

- [ ] Public launch announcement  
- [ ] Live apps on Play Store + App Store  
- [ ] Launch KPI dashboard (orders/day, AOV, delivery SLA, NPS)  
- [ ] Incident log + resolution report (first 72 hours)  
- [ ] Post-launch retrospective document  
- [ ] Phase 2 roadmap (growth features) approved  

---

## Launch KPI Targets (First 30 Days)

| Metric | Target |
|--------|--------|
| Daily orders | 30 → 100 (ramp) |
| Delivery SLA (≤30 min) | ≥85% |
| Payment success rate (online) | ≥98% |
| App crash rate | <0.5% |
| API uptime | ≥99.5% |
| Customer support response | <15 min |
| App store rating | ≥4.0 |

---

## Cross-Phase Dependency Matrix

| Phase | Depends On | Blocks |
|-------|------------|--------|
| P1 Planning | — | All |
| P2 Backend | P1 | P3, P4, P5, P6 |
| P3 Customer App | P2 (API freeze), P6 (payments) | P7, P9 |
| P4 Admin | P2 | P5 (rider accounts), P7 |
| P5 Rider | P2, P4 | P7, P9 |
| P6 Payments | P1 (merchant KYC), P2 | P3 checkout, P7 |
| P7 Testing | P2–P6 on staging | P8 |
| P8 Deployment | P7 sign-off | P9 |
| P9 Launch | P8, ops readiness | — |

---

## Critical Path & Acceleration Options

**Critical path (sequential):**  
P1 → P2 API freeze → P3 checkout + P6 payments → P7 E2E → P8 prod deploy → P9 launch

**Parallelization opportunities:**

- P3 (customer), P4 (admin), and P5 (rider) overlap after week 4 — same Flutter codebase, different role entry points  
- P6 (payments) runs parallel with P3 from week 8  
- P8 (infra provisioning) can start during P7 testing on staging  

**Acceleration (reduce timeline by ~3 weeks):**

- Defer wishlist backend sync and FCM to post-launch  
- COD-only soft launch; enable PhonePe in week 2  
- Defer admin order export and tablet layouts to post-launch  

---

## Budget Estimate (Engineering + Infra, Launch Phase)

| Category | Monthly | Launch Total (5 mo) |
|----------|---------|---------------------|
| Engineering team (7–8 FTE) | ₹10–16L | ₹50–80L |
| Infrastructure (VPS, Cloudflare, APIs) | ₹25–40K | ₹1.5L |
| Third-party (MSG91, Maps, PhonePe fees) | Variable | ₹50K setup |
| QA devices + tools | One-time | ₹1L |
| App store fees | One-time | ₹20K |
| **Total (engineering-heavy)** | | **₹53–83L** |

*Excludes inventory, rider wages, marketing, and store rent.*

---

## Phase Gate Criteria (Go/No-Go)

| Gate | Criteria |
|------|----------|
| P1 → P2 | MVP scope signed; API spec approved; vendors engaged |
| P2 → P3 | Auth, catalog, cart, orders APIs stable on staging; security review passed |
| P3–P5 → P7 | All apps connect to staging; checkout works COD + sandbox PhonePe |
| P7 → P8 | Zero P0 bugs; ≤3 P1 bugs with workarounds; load test passed |
| P8 → P9 | 48h production uptime; smoke tests pass; backups verified |
| P9 Go-Live | Ops ready (riders, stock); support channel live; war room staffed |

---

## Post-Launch Roadmap (Phase 10+)

Prioritized for weeks 5–12 after launch:

1. FCM push notifications + order status alerts  
2. Wishlist backend sync + reorder  
3. PhonePe native SDK (better conversion)  
4. Admin order export + tablet-optimized layouts  
5. Subscription ("Meatvo Prime")  
6. Multi-store / second dark store in Bokaro  
7. Analytics pipeline (GMV funnel, cohort retention)  
8. Database read replicas + horizontal API scaling  
9. Optional: separate Flutter build flavors (customer / admin / rider APKs)  

---

## Related Documents

| Document | Path |
|----------|------|
| Product Requirements | `docs/PRODUCT_REQUIREMENTS_DOCUMENT.md` |
| UI/UX Specification | `docs/UI_UX_SPECIFICATION.md` |
| Technical Roadmap (36-month) | `docs/TECHNICAL_ROADMAP.md` |
| API Specification | `docs/API_SPECIFICATION.yaml` |
| System Architecture | `docs/SYSTEM_ARCHITECTURE.md` |
| Infrastructure & DevOps | `docs/INFRASTRUCTURE.md` |
| Security Reports | `docs/security/` |

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | June 13, 2026 | CTO Office | Initial complete implementation roadmap |
| 1.1 | June 13, 2026 | CTO Office | Flutter-only frontend; removed web admin/customer/rider scope |
