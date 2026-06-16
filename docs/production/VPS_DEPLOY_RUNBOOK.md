# VPS Deployment Runbook

Production deployment uses the scripts in `scripts/` at repo root. Run on the target VPS with production env configured from `backend/.env.vps.example`.

## Pre-flight (local)

```bash
cd backend
NODE_ENV=production npm run production:check
npm run smoke
```

## Phase 1 — Server hardening (VPS as root)

```bash
bash scripts/vps-phase1-setup.sh
bash scripts/vps-phase1-verify.sh
```

## Phase 2 — App deploy

Copy `.env.vps.example` to `.env` on the server, fill all secrets (JWT, DB, Redis, MSG91, PhonePe, FCM_SERVER_KEY, SENTRY_DSN), then:

```bash
bash scripts/vps-phase2-deploy.sh
```

## Phase 3 — SSL

```bash
bash scripts/vps-phase3-ssl.sh
```

## Post-deploy verification

```bash
cd backend
npm run smoke
npm run smoke:customer   # requires OTP
curl https://your-domain/health
```

## Flutter release

```bash
cd frontend
flutter build appbundle --release --dart-define-from-file=env.production.json
```

Ensure `env.production.json` contains production `API_BASE_URL` and `SENTRY_DSN` (see `env.production.example.json`).
