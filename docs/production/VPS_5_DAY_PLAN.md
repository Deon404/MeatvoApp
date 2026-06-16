# Meatvo Backend — 5-Day VPS Production Plan (Hostinger KVM 1)

Target: **1 vCPU, 4 GB RAM, 50 GB SSD** — sufficient for Node.js + PostgreSQL + Redis + Nginx.

---

## Day 1 — VPS foundation + secrets

### On Hostinger panel
1. Create Ubuntu 22.04 or 24.04 VPS (KVM 1).
2. Note **server IP** and set root password / SSH key.
3. Point your domain **A record** → VPS IP (`api.yourdomain.com` or root domain).

### On VPS (SSH as root)
```bash
export MEATVO_DB_PASSWORD='$(openssl rand -base64 24)'
export MEATVO_REDIS_PASSWORD='$(openssl rand -base64 24)'
cd /opt && git clone YOUR_REPO_URL meatvo && cd meatvo
bash scripts/vps-phase1-setup.sh
```

Phase 1 installs: Node 20, PM2, PostgreSQL, Redis (password-protected), Nginx, UFW (22/80/443 only).

### Generate production secrets (local or VPS)
```bash
openssl rand -hex 32   # repeat for each secret below
```

| Variable | Notes |
|----------|-------|
| `JWT_ACCESS_SECRET` | 32+ chars |
| `JWT_REFRESH_SECRET` | 32+ chars, different from access |
| `OTP_HASH_SECRET` | 32+ chars |
| `MFA_ENCRYPTION_KEY` | 32+ chars |
| `UPLOAD_SIGNING_SECRET` | 32+ chars |
| `DB_PASSWORD` | From Phase 1 |
| `REDIS_URL` | `redis://:PASSWORD@127.0.0.1:6379` |

Copy template and fill:
```bash
cp backend/.env.vps.example backend/.env
nano backend/.env
```

**Must set:** MSG91 live keys, PhonePe production keys, real `SENTRY_DSN`, `CORS_ORIGINS=https://yourdomain.com`, replace all `CHANGE_ME` / `YOUR_DOMAIN`.

Validate locally before deploy:
```bash
cd backend && NODE_ENV=production npm run production:check
```

---

## Day 2 — Deploy backend + smoke test

```bash
bash scripts/vps-phase2-deploy.sh
```

This: `npm ci`, runs schema/migrations, starts PM2 (`meatvo-backend`), configures Nginx proxy to `127.0.0.1:8080`.

Verify:
```bash
curl -s http://127.0.0.1:8080/health | jq
pm2 status
pm2 logs meatvo-backend --lines 50
```

From your machine (before SSL, use HTTP or `-k`):
```bash
curl http://YOUR_SERVER_IP/health
```

Run smoke test against live server:
```bash
BACKEND_TEST_BASE_URL=https://api.yourdomain.com npm run smoke
```

---

## Day 3 — SSL + hardening

```bash
bash scripts/vps-phase3-ssl.sh
```

Update `.env` with HTTPS URLs:
- `PHONEPE_REDIRECT_URL=https://yourdomain.com/payment/return`
- `PHONEPE_WEBHOOK_URL=https://yourdomain.com/api/payments/phonepe/webhook`
- `CORS_ORIGINS=https://yourdomain.com`

Restart:
```bash
pm2 restart meatvo-backend --env production
```

Security checklist:
- [ ] `DEV_AUTH_BYPASS_ENABLED=false`
- [ ] `OTP_LOG_TO_CONSOLE=false`
- [ ] `DISABLE_API_RATE_LIMIT` unset or `false`
- [ ] `REDIS_ALLOW_FALLBACK` unset or `false`
- [ ] UFW: only 22, 80, 443 open
- [ ] Port 8080 **not** exposed publicly (Nginx only)

---

## Day 4 — Integrations + admin setup

1. **MSG91** — live auth key, template ID, sender ID; test OTP login end-to-end.
2. **PhonePe** — production merchant ID + salt; test ₹1 payment + webhook.
3. **Google Maps** — restrict API key to Android app + server IP.
4. **Firebase** — project keys for admin web push (if used).
5. **Sentry** — confirm errors appear in dashboard.

Admin bootstrap:
- Create admin user via DB or first OTP login + role update.
- Add products, categories, delivery slots (today + 2 days).
- Set delivery charge, min order, radius in admin settings.

---

## Day 5 — Load test + backup + go-live

### Backups (cron on VPS)
```bash
# Daily DB backup example (adjust paths)
0 2 * * * pg_dump -U meatvo_user meatvo_db | gzip > /var/backups/meatvo_$(date +\%Y\%m\%d).sql.gz
```

### Final checks
```bash
NODE_ENV=production npm run production:check
npm run smoke
```

| Endpoint | Expected |
|----------|----------|
| `GET /health` | `{ status: "ok", db: "connected" }` |
| `GET /api/v1/categories` | 200 + list |
| `GET /api/v1/products?limit=5` | 200 + products |
| `POST /api/auth/send-otp` | 429 after abuse (rate limit) |
| `GET /api/delivery/slots` | 200, no `allSlots` field |

### PM2 auto-start on reboot
```bash
pm2 save
pm2 startup
```

### Monitor
```bash
pm2 monit
htop
tail -f backend/logs/combined.log
```

---

## Resource budget (KVM 1)

| Service | Typical RAM |
|---------|-------------|
| PostgreSQL | ~200–400 MB |
| Redis | ~50–100 MB |
| Node (PM2, 1 instance) | ~150–300 MB |
| Nginx | ~20 MB |
| **Headroom** | ~3 GB for spikes |

Use **1 PM2 instance** on KVM 1 (`PM2_INSTANCES=1` in ecosystem.config.js). Scale to cluster only on larger VPS.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Server exits on start | Run `production:check` — missing/weak env |
| 502 Bad Gateway | `pm2 logs`, check Redis/Postgres running |
| OTP not delivered | Verify MSG91 keys, sender ID approved |
| Payment webhook fails | HTTPS required; check PhonePe dashboard URL |
| CORS errors | Add Flutter/web origin to `CORS_ORIGINS` |

---

## Backend security fixes included (code)

- Redis cache invalidation uses `SCAN` + `DEL` (not broken glob `DEL`)
- Customer slots API no longer leaks `allSlots`
- Coupon validate endpoint rate-limited
- Production env rejects weak secrets, dev bypass, OTP console logging
- `npm run production:check` pre-deploy validator

See also: `docs/security/FINAL_SECURITY_VERDICT.md`, `backend/.env.vps.example`.
