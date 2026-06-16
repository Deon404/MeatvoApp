# VPS Security Checklist — Hostinger KVM Ubuntu 24.04

**Target:** Meatvo production backend  
**Reference script:** `scripts/vps-phase1-setup.sh`

---

## Pre-Deploy

- [ ] Rotate all secrets (JWT, OTP, DB, Redis, PhonePe, MSG91, Firebase, Maps)
- [ ] Copy `backend/.env.vps.example` → production `.env` with strong values
- [ ] Verify `.env` is NOT in git
- [ ] Set `NODE_ENV=production`
- [ ] Set `REDIS_URL` with password (required — app exits without it)
- [ ] Set `TRUST_PROXY=true`
- [ ] Disable `DEV_AUTH_BYPASS_ENABLED` (or unset)
- [ ] Set `CORS_ORIGINS` to production domains only
- [ ] Set `METRICS_ALLOWED_IPS` to monitoring server IPs

---

## Firewall (UFW)

- [ ] Allow SSH (22/tcp) — restrict to your IP if possible
- [ ] Allow HTTP (80/tcp)
- [ ] Allow HTTPS (443/tcp)
- [ ] **Do NOT** expose 8080, 5432, 6379 publicly
- [ ] `ufw enable` and verify with `ufw status verbose`

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

---

## Fail2ban

- [ ] Install: `apt install fail2ban`
- [ ] Enable SSH jail: `/etc/fail2ban/jail.local`
- [ ] Optional: Nginx rate-limit jail for auth endpoints
- [ ] `systemctl enable fail2ban && systemctl start fail2ban`

---

## Nginx

- [ ] Reverse proxy to `127.0.0.1:8080`
- [ ] SSL via Let's Encrypt (Certbot)
- [ ] Set `X-Forwarded-Proto`, `X-Real-IP` headers
- [ ] Rate limit `/api/auth/*` at Nginx layer (optional extra layer)
- [ ] Block direct access to `/uploads` if moving to signed URLs
- [ ] WebSocket proxy for `/ws` path

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
location /ws {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

---

## PM2

- [ ] `pm2 start backend/index.js --name meatvo-api`
- [ ] `pm2 save`
- [ ] `pm2 startup` (systemd integration)
- [ ] Set `max_memory_restart` (e.g., 512M)
- [ ] Configure log rotation

---

## PostgreSQL

- [ ] Bind to `127.0.0.1` only (`/etc/postgresql/*/main/postgresql.conf`)
- [ ] Strong password for `meatvo_user`
- [ ] `pg_hba.conf` — local connections only
- [ ] Enable automated backups (pg_dump cron or managed backup)
- [ ] Run `ensureSchema` on first deploy

```bash
# postgresql.conf
listen_addresses = 'localhost'
```

---

## Redis

- [ ] Bind to `127.0.0.1` (`bind 127.0.0.1` in redis.conf)
- [ ] Set `requirepass` strong password
- [ ] `REDIS_URL=redis://:PASSWORD@127.0.0.1:6379`
- [ ] Disable dangerous commands: `rename-command FLUSHALL ""`
- [ ] Set `maxmemory` and `maxmemory-policy allkeys-lru`

---

## SSL/TLS

- [ ] Certbot: `certbot --nginx -d api.yourdomain.com`
- [ ] Auto-renewal: `certbot renew --dry-run`
- [ ] HSTS enabled (Helmet + Nginx `add_header Strict-Transport-Security`)

---

## Backups

- [ ] Daily PostgreSQL dump to off-server storage
- [ ] Redis RDB snapshots (if persistence needed)
- [ ] `.env` backup in secure vault (not on server plaintext)
- [ ] Upload directory backup if using local storage

```bash
# Cron example
0 3 * * * pg_dump -U meatvo_user meatvo_db | gzip > /backups/meatvo_$(date +\%Y\%m\%d).sql.gz
```

---

## Monitoring

- [ ] Health probes: `GET /health/ready`, `GET /health/live` (no IP restriction)
- [ ] Detailed health: `GET /health/comprehensive` (IP-restricted)
- [ ] Sentry DSN configured
- [ ] Uptime monitoring on `/health/ready`
- [ ] Disk/memory alerts
- [ ] PM2 monitoring or `pm2 monit`

---

## Post-Deploy Verification

- [ ] `curl https://api.yourdomain.com/health/ready` → 200
- [ ] OTP send/verify flow works
- [ ] Payment webhook reachable from PhonePe
- [ ] Socket.io connects with JWT
- [ ] Admin panel accessible with RBAC
- [ ] Port scan confirms 5432/6379/8080 not public
