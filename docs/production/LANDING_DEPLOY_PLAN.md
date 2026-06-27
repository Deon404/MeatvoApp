# Landing Page + Nginx Routing — Implementation Plan

**Goal:** Serve a marketing landing page at `https://meatvo.com/` while keeping the API at `https://meatvo.com/api/*` (Flutter mobile app unchanged).

**Scope:** Landing + API only. **No web SPAs** — no `/customer`, `/admin`, or `/delivery` web apps. All ordering/rider/admin UX stays in the Flutter app.

**Status:** Implemented in repo — deploy to VPS with commands below.

---

## Current state

| URL | Today | Desired |
|-----|-------|---------|
| `meatvo.com/` | Backend JSON (`{ status: "ok", service: "meatvo-backend" }`) | Marketing landing HTML |
| `meatvo.com/api/*` | Backend API (via nginx → `:8080`) | Same |
| `meatvo.com/ws` | Socket.io | Same |
| Flutter `API_BASE_URL` | `https://meatvo.com` → app calls `/api/...` | **No change needed** |

**Key finding:** A complete landing page already exists at `docs/index.html` with assets in `docs/assets/` (logo, hero, category images). It is **not deployed** by any script today.

**Config drift:** VPS phase scripts (`vps-phase1-setup.sh`, `vps-phase3-ssl.sh`) install a minimal “proxy everything to `:8080`” nginx config. The richer template `scripts/nginx-meatvo.conf` is documented but **not auto-installed** and still proxies `/` to the backend.

---

## Recommended approach

**Nginx static landing + backend proxy for API paths** (Option A).

Why this over changing `backend/index.js` to serve HTML at `/`:

- Landing is pure static — no Node process needed for marketing traffic
- Clear separation: nginx owns `/`, backend owns `/api`, `/ws`, `/uploads`
- Easier to cache and update landing without redeploying the API
- Matches the architecture you described (`meatvo.com` = marketing, `/api` = backend)

### Target architecture

```
Browser (landing) / Flutter app (API)
        │
        ▼
   Nginx (443)
        │
        ├── /api/*     ──proxy──► 127.0.0.1:8080 (Node backend)
        ├── /ws        ──proxy──► 127.0.0.1:8080 (Socket.io — Flutter tracking)
        ├── /uploads/* ──proxy──► 127.0.0.1:8080
        ├── /health    ──proxy──► 127.0.0.1:8080 (localhost only)
        └── /          ──static──► /var/www/meatvo-landing/
```

**Not in scope:** `/customer`, `/admin`, `/delivery` web routes — not proxied, not built.

---

## Alternatives considered

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **A. Nginx static** (`/var/www/meatvo-landing`) | Fast, standard, no API coupling | Requires nginx + deploy script updates | **Recommended** |
| **B. Backend `GET /` serves `docs/index.html`** | Single deploy artifact | Marketing traffic hits Node; mixes concerns | Fallback only |
| **C. `api.meatvo.com` subdomain for API** | Clean split | Extra DNS/cert; Flutter env change | Optional later |
| **D. Rebuild landing from scratch** | Full control | Wastes existing `docs/index.html` | Not needed |

---

## Implementation phases

### Phase 1 — Repo: landing source of truth

1. Create `landing/` at repo root (or promote `docs/` → `landing/`):
   - Move or copy `docs/index.html` → `landing/index.html`
   - Copy `docs/assets/` → `landing/assets/`
   - Fix any relative paths if folder structure changes (`assets/logo.png` etc.)

2. Minor landing updates (optional, same phase):
   - Add “Download on Google Play” CTA (placeholder `#` until Play Store link exists)
   - Ensure contact/location copy matches production (Bokaro, Jharkhand)
   - Add `favicon` from `frontend/web/favicon.png`

3. **Do not change** `frontend/env.production.json` — `API_BASE_URL: https://meatvo.com` is correct.

### Phase 2 — Repo: nginx template

Update `scripts/nginx-meatvo.conf`:

- Replace catch-all `location / { proxy_pass ... }` with:
  ```nginx
  root /var/www/meatvo-landing;
  index index.html;
  try_files $uri $uri/ /index.html;
  ```
- Add explicit backend proxy blocks **before** `/`:
  - `/api/`, `/ws`, `/uploads/`, `/health`, `/metrics` only
  - Do **not** add `/customer`, `/admin`, `/delivery` proxy blocks
- Create `scripts/nginx-meatvo-proxy.conf` snippet (currently only commented inline — **not deployed today**)
- Mirror changes in `scripts/nginx-killexotic.conf` (duplicate) or delete duplicate later

Update `nginx/conf.d/meatvo.conf` (Docker path) for consistency — lower priority if VPS is primary.

### Phase 3 — Repo: deploy hooks

Extend **`scripts/vps-phase2-deploy.sh`**:

```bash
LANDING_DIR=/var/www/meatvo-landing
mkdir -p "$LANDING_DIR"
rsync -a --delete "${APP_DIR}/landing/" "$LANDING_DIR/"
chown -R www-data:www-data "$LANDING_DIR"
```

Extend **`scripts/deploy.sh`** (repeatable updates) with the same `step_landing` sync.

Extend **`scripts/vps-pack-deploy.ps1`** — ensure `landing/` is included in tarball (it will be by default; `frontend/` stays excluded).

Update **`scripts/vps-phase3-ssl.sh`** `prepare_nginx_acme()` — after certbot, install full `nginx-meatvo.conf` (with domain substitution) instead of minimal proxy-only config, **or** run a new `scripts/vps-install-nginx.sh` that:
1. Substitutes `YOUR_DOMAIN` → `meatvo.com`
2. Copies config to `/etc/nginx/sites-available/meatvo`
3. Copies snippet to `/etc/nginx/snippets/meatvo-proxy.conf`
4. Runs `nginx -t && systemctl reload nginx`

Update **`docs/DEPLOYMENT_FRONTEND.md`** — document landing at `/`, API at `/api`, mobile-only (no web SPAs).

### Phase 4 — VPS: one-time + deploy

**On VPS (after code is merged):**

```bash
# 1. Deploy updated repo (existing flow)
bash /opt/meatvo/scripts/vps-phase2-deploy.sh   # now syncs landing/

# 2. Install nginx config (new or manual)
MEATVO_DOMAIN=meatvo.com bash /opt/meatvo/scripts/vps-install-nginx.sh

# 3. Verify
curl -sI https://meatvo.com/ | head -5          # Content-Type: text/html
curl -s https://meatvo.com/api/store/status     # JSON from API
```

If SSL was already set up via phase 3, **re-run nginx install** — certbot-managed SSL blocks must be preserved (install script should not overwrite `/etc/letsencrypt` paths).

---

## Files to create / modify

| File | Action |
|------|--------|
| `landing/index.html` | Create (from `docs/index.html`) |
| `landing/assets/*` | Create (from `docs/assets/`) |
| `scripts/nginx-meatvo.conf` | Update routing |
| `scripts/nginx-meatvo-proxy.conf` | Create snippet file |
| `scripts/vps-install-nginx.sh` | Create — install + domain substitute |
| `scripts/vps-phase2-deploy.sh` | Add `step_landing` rsync |
| `scripts/deploy.sh` | Add `step_landing` |
| `scripts/vps-phase3-ssl.sh` | Call nginx install post-certbot (optional) |
| `docs/DEPLOYMENT_FRONTEND.md` | Document new layout |
| `docs/production/LANDING_DEPLOY_PLAN.md` | This file |

**No changes:**

- `frontend/env.production.json` (`API_BASE_URL` stays `https://meatvo.com`)
- `backend/index.js` (optional: add comment that `/` is nginx-owned in production)

---

## Verification checklist

### Local (before VPS)

- [ ] Open `landing/index.html` in browser — images, nav, sections render
- [ ] All asset paths resolve (`assets/logo.png`, etc.)

### VPS (after deploy)

- [ ] `https://meatvo.com/` → HTML landing (not JSON)
- [ ] `https://meatvo.com/assets/logo.png` → 200
- [ ] `https://meatvo.com/api/store/status` → JSON API response
- [ ] `https://meatvo.com/health` → blocked externally or 403 (nginx allow list)
- [ ] Flutter release build still connects (`API_BASE_URL=https://meatvo.com`)
- [ ] `nginx -t` passes; `systemctl reload nginx` succeeds

### Regression

- [ ] Socket.io `/ws` still works for Flutter order tracking
- [ ] Certbot renewal unaffected (`/.well-known/acme-challenge/`)
- [ ] Unknown paths (e.g. `/customer`) fall through to landing `index.html` or 404 — acceptable

---

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Phase 3 SSL script overwrites nginx config | New `vps-install-nginx.sh` becomes single source; phase 3 calls it after certbot |
| `nginx-meatvo-proxy.conf` missing on server | Ship snippet in repo; install script copies it |
| Certbot modifies nginx config | Install script merges with existing SSL directives or documents manual merge |
| Landing stale after deploy | `step_landing` in `deploy.sh` rsyncs on every deploy |

---

## Effort estimate

| Phase | Effort |
|-------|--------|
| Phase 1 — landing folder | ~30 min |
| Phase 2 — nginx template | ~45 min |
| Phase 3 — deploy scripts | ~45 min |
| Phase 4 — VPS apply + test | ~30 min |
| **Total** | **~2.5 hours** |

---

## Out of scope (explicitly excluded)

- **Web SPAs** — `/customer`, `/admin`, `/delivery` (mobile Flutter app only)
- `api.meatvo.com` subdomain split (optional later)
- Warm-light landing redesign to match `MeatvoColors` (current dark page is fine)

## Follow-ups (optional)

- Google Play Store link on landing (after AAB publish)

---

## Next step

### VPS deploy (after pushing code)

```bash
# On Windows — pack and upload
powershell -ExecutionPolicy Bypass -File scripts/vps-pack-deploy.ps1
# scp meatvo-deploy.tar.gz to VPS, extract to /opt/meatvo

# On VPS
bash /opt/meatvo/scripts/vps-phase2-deploy.sh
MEATVO_DOMAIN=meatvo.com bash /opt/meatvo/scripts/vps-install-nginx.sh

# If SSL not yet configured:
MEATVO_DOMAIN=meatvo.com bash /opt/meatvo/scripts/vps-phase3-ssl.sh

# Verify
curl -sI https://meatvo.com/ | head -3          # text/html
curl -s https://meatvo.com/api/store/status     # JSON
```
