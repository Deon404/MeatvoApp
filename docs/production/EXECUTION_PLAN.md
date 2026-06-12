# Execution Plan

## Step 1 — Security Fixes (DONE)

- **Files**: `orders.controller.js`, `auth.middleware.js`, `phonepeChecksum.js`, `auth.controller.js`
- **Validation**: Module load test, ownership logic review
- **Rollback**: `git revert`

## Step 2 — Database Schema (DONE)

- **Files**: `ensureSchema.js`, `migrations/006_add_missing_columns.sql`
- **Commands**: `node run-migrations.js` on server
- **Validation**: `\d orders` shows `updated_at`
- **Rollback**: Restore DB backup

## Step 3 — Deployment Scripts (DONE)

- **Files**: `vps-phase3-ssl.sh`, `backup/postgres-backup.sh`, `vps-phase1-setup.sh`
- **Validation**: `bash -n scripts/*.sh`
- **Rollback**: N/A (new files)

## Step 4 — Environment Templates (DONE)

- **Files**: `.env.vps.example`, `env-manifest.json`, Docker/K8s MSG91_AUTH_KEY
- **Validation**: `validateEnv()` with production template
- **Rollback**: Restore templates

## Step 5 — Backend Infra (DONE)

- **Files**: `index.js`, `redis.js`
- **Validation**: SIGTERM handler, Sentry init log
- **Rollback**: `git revert`

## Step 6 — Flutter Release Prep (DONE)

- **Files**: `build.gradle.kts`, `env_config.dart`, `pubspec.yaml`
- **Commands**: `flutter build appbundle --release --dart-define-from-file=env.production.json`
- **Validation**: APK not signed with debug keystore when keystore set
- **Rollback**: `git revert`

## Step 7 — VPS Phase 1 (OPERATOR)

- **Command**: `MEATVO_DB_PASSWORD=... MEATVO_REDIS_PASSWORD=... bash vps-phase1-setup.sh`
- **Validation**: `vps-phase1-verify.sh`
- **Rollback**: VPS snapshot restore

## Step 8 — VPS Phase 2 Deploy (OPERATOR)

- **Command**: `bash vps-phase2-deploy.sh`
- **Validation**: `curl http://localhost/health`
- **Rollback**: `pm2 delete meatvo-backend`

## Step 9 — SSL Phase 3 (OPERATOR)

- **Command**: `MEATVO_DOMAIN=... bash vps-phase3-ssl.sh`
- **Validation**: HTTPS in browser, certbot renew --dry-run
- **Rollback**: Remove SSL server block

## Step 10 — Smoke Test (OPERATOR)

- OTP login → browse → cart → COD checkout → order tracking
- **Validation**: All flows return 200
- **Rollback**: Maintenance mode
