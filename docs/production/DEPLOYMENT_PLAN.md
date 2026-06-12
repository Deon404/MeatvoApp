# Deployment Plan — Ubuntu VPS

## Phase 1: Server Preparation

**Script**: `scripts/vps-phase1-setup.sh`

```bash
MEATVO_DB_PASSWORD='...' MEATVO_REDIS_PASSWORD='...' bash scripts/vps-phase1-setup.sh
```

Installs: Node 20, PM2, PostgreSQL, Redis (password), Nginx, UFW (22/80/443 only)

## Phase 2: Database Preparation

```bash
psql -U meatvo_user -d meatvo_db -f backend/src/db/schema.sql
cd backend && node run-migrations.js
node src/db/migrations/migrate_order_statuses.js  # if needed
```

## Phase 3: Backend Deployment

```bash
# From Windows: scripts/vps-pack-deploy.ps1
# On VPS:
cd /opt/meatvo/backend
cp .env.vps.example .env && nano .env
npm ci --omit=dev
pm2 start ecosystem.config.js --env production
pm2 save && pm2 startup systemd
```

## Phase 4: Frontend Deployment

No separate step — backend serves `/admin`, `/customer`, `/delivery` SPAs.

Flutter mobile: build with `--dart-define-from-file=env.production.json`

## Phase 5: Socket Deployment

Included in backend. Nginx WebSocket headers configured in Phase 1.

## Phase 6: Payment Deployment

Set in `.env`:
- `PHONEPE_MERCHANT_ID`, `PHONEPE_SALT_KEY`
- `PHONEPE_REDIRECT_URL`, `PHONEPE_WEBHOOK_URL` (HTTPS after Phase 7)

## Phase 7: SSL (Phase 3 Script)

```bash
MEATVO_DOMAIN=meatvo.com bash scripts/vps-phase3-ssl.sh
```

## Phase 8: Monitoring

- Sentry DSN in `.env` (initialized at boot)
- `METRICS_ALLOWED_IPS` for Prometheus scrape
- PM2 logs: `pm2 logs meatvo-backend`

## Phase 9: Backup

```bash
# Cron: 0 2 * * * /opt/meatvo/scripts/backup/postgres-backup.sh
```

## Phase 10: Disaster Recovery

1. Restore DB: `gunzip -c backup.sql.gz | psql -U meatvo_user -d meatvo_db`
2. Redeploy tarball to `/opt/meatvo`
3. `pm2 restart meatvo-backend`
