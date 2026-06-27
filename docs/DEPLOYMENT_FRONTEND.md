# Frontend Deployment Model

Meatvo production uses **static marketing landing** + **Node.js API**. There are **no web SPAs** (no `/customer`, `/admin`, or `/delivery` web apps). Customer, rider, and admin UX is the **Flutter mobile app** only.

## Architecture (VPS)

| Path | Content |
|------|---------|
| `/` | Marketing landing (`landing/` → `/var/www/meatvo-landing`) |
| `/api/*` | REST API (Node backend on `:8080`) |
| `/ws` | Socket.io (Flutter live tracking) |
| `/uploads/*` | Product images (proxied to backend) |

Nginx terminates TLS and routes by path. See `scripts/nginx-meatvo.conf`.

## Landing deploy

Source of truth: `landing/index.html` + `landing/assets/`.

On VPS:

```bash
# Sync landing files (also runs inside phase2/deploy)
bash -c 'source /opt/meatvo/scripts/lib/sync-landing.sh && meatvo_sync_landing'

# Install nginx routing (after SSL certs exist)
MEATVO_DOMAIN=meatvo.com bash /opt/meatvo/scripts/vps-install-nginx.sh
```

Phase 2 (`vps-phase2-deploy.sh`) syncs landing. Phase 3 (`vps-phase3-ssl.sh`) installs nginx config after Certbot.

## Flutter mobile

Build from `frontend/` with:

```bash
flutter build appbundle --release --dart-define-from-file=env.production.json
```

Set `API_BASE_URL` to the site root (no `/api` suffix), e.g. `https://meatvo.com`. The app appends `/api` automatically.

## Docker/Kubernetes (optional)

`docker-compose.production.yml` and `nginx/conf.d/meatvo.conf` describe a split-container setup. The current VPS path uses bare-metal Nginx + PM2 only.

## Legacy backend SPA routes

`backend/index.js` still has `/customer`, `/admin`, `/delivery` handlers for optional future web bundles. They are **not** proxied in production nginx and are **out of scope** for the current mobile-only product.
