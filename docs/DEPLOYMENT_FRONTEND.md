# Frontend Deployment Model

Meatvo does **not** use a separate frontend container on the VPS path.

## Architecture

The Node.js backend (`backend/index.js`) serves:

| Path | Content |
|------|---------|
| `/admin`, `/admin/*` | Admin web SPA (from `admin/` when present) |
| `/customer`, `/customer/*` | Customer web SPA |
| `/delivery`, `/delivery/*` | Delivery rider web SPA |
| `/api/*` | REST API |
| `/ws` | Socket.io |

## VPS Deployment

1. Deploy only the backend via `scripts/vps-phase2-deploy.sh`
2. Nginx proxies all traffic to `localhost:8080`
3. No `Dockerfile.frontend` is required for VPS

## Docker/Kubernetes (future)

`docker-compose.production.yml` references a separate `frontend` image for a split deployment model. That path is optional and not used by the current VPS scripts.

## Flutter Mobile

Customer/rider/admin mobile apps are built from `old_meatvo/` and connect to the same backend API.
