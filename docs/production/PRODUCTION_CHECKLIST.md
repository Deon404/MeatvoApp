# Production Checklist — Meatvo on Hostinger KVM

**Target:** Ubuntu 24.04 | Node 20 | PM2 | PostgreSQL | Redis | Nginx | Certbot

---

## Server

- [ ] Ubuntu 24.04 updated (`apt update && apt upgrade`)
- [ ] UFW: allow 22, 80, 443 only — **deny 8080**
- [ ] Non-root `meatvo` system user (optional hardening)
- [ ] fail2ban for SSH (recommended)
- [ ] Run `scripts/vps-phase1-setup.sh` with `MEATVO_DB_PASSWORD` and `MEATVO_REDIS_PASSWORD`
- [ ] Run `scripts/vps-phase1-verify.sh`

---

## Database

- [ ] PostgreSQL running (`systemctl status postgresql`)
- [ ] Database `meatvo_db` and user `meatvo_user` created
- [ ] Schema applied: `psql -f backend/src/db/schema.sql`
- [ ] Migrations: `node backend/run-migrations.js`
- [ ] Extended statuses: `node backend/src/db/migrations/migrate_order_statuses.js`
- [ ] Verify columns: `\d orders` shows `updated_at`
- [ ] Backup cron: `0 2 * * * /opt/meatvo/scripts/backup/postgres-backup.sh`

---

## Redis

- [ ] Redis bound to 127.0.0.1 only
- [ ] `requirepass` set in `/etc/redis/redis.conf`
- [ ] `REDIS_URL=redis://:PASSWORD@127.0.0.1:6379` in backend `.env`
- [ ] `redis-cli -a PASSWORD ping` → PONG

---

## PM2

- [ ] `cd /opt/meatvo/backend && pm2 start ecosystem.config.js --env production`
- [ ] `pm2 save && pm2 startup systemd`
- [ ] Logs: `backend/logs/pm2-*.log`
- [ ] Memory limit: 512M (adjust via `PM2_MAX_MEMORY`)

---

## Nginx

- [ ] Config: `scripts/nginx-meatvo.conf` → `/etc/nginx/sites-available/meatvo`
- [ ] Snippet: `/etc/nginx/snippets/meatvo-proxy.conf`
- [ ] WebSocket headers for `/ws`
- [ ] Rate limiting zones for `/api/auth/*`
- [ ] `nginx -t && systemctl reload nginx`

---

## SSL

- [ ] DNS A records point to VPS IP
- [ ] Run `MEATVO_DOMAIN=yourdomain.com bash scripts/setup-ssl.sh`
- [ ] Certbot auto-renewal: `certbot renew --dry-run`
- [ ] Set `ENFORCE_HTTPS=true` in backend `.env`
- [ ] Update PhonePe URLs to HTTPS

---

## Backups

- [ ] `scripts/backup/postgres-backup.sh` executable
- [ ] Cron scheduled (daily 2 AM)
- [ ] Test restore to staging DB
- [ ] Redis AOF enabled (`appendonly yes`)

---

## Monitoring

- [ ] Sentry DSN configured (real project)
- [ ] External uptime monitor on `/health/live`
- [ ] `METRICS_ALLOWED_IPS` for Prometheus scraper (optional)
- [ ] Disk space alert (>80%)

---

## Logging

- [ ] Winston logs: `backend/logs/error.log`, `combined.log`
- [ ] PM2 log rotation: `/etc/logrotate.d/meatvo`
- [ ] Nginx access/error logs reviewed weekly

---

## Security

- [ ] All P0 env vars set (see ENVIRONMENT_AUDIT.md)
- [ ] `TRUST_PROXY=true`
- [ ] `DEV_AUTH_BYPASS_ENABLED=false`
- [ ] `CORS_ALLOW_NULL_ORIGIN=false`
- [ ] JWT secrets: `openssl rand -hex 32` (unique access + refresh)
- [ ] Firebase API key restricted in console
- [ ] PhonePe sandbox webhook tested before production keys

---

## Deployment

- [ ] Code at `/opt/meatvo` (git clone or tarball via `vps-pack-deploy.ps1`)
- [ ] `backend/.env` from `.env.production.example`
- [ ] `bash scripts/deploy.sh` for updates
- [ ] Smoke test: OTP login → browse → cart → COD order → cancel

---

## Mobile (Flutter)

- [ ] Release keystore generated and secured
- [ ] `API_BASE_URL=https://yourdomain.com` via dart-define
- [ ] No backend secrets in Flutter env
- [ ] `flutter build appbundle --release`
- [ ] Play Store internal track test

---

## Go-Live Sign-Off

| Role | Sign-off |
|------|----------|
| Backend | |
| DevOps | |
| Security | |
| Product | |
