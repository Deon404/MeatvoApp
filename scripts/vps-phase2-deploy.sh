#!/usr/bin/env bash
# Meatvo VPS Phase 2 — backend deploy (run on server as root)
# Prerequisites: Phase 1 complete, code at /opt/meatvo, backend/.env configured
#
#   cd /opt/meatvo
#   bash scripts/vps-phase2-deploy.sh

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meatvo}"
BACKEND_DIR="${APP_DIR}/backend"
DB_NAME="${MEATVO_DB_NAME:-meatvo_db}"
PM2_APP="meatvo-backend"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: Run as root" >&2
    exit 1
  fi
}

require_backend() {
  if [[ ! -f "${BACKEND_DIR}/package.json" ]]; then
    echo "ERROR: Backend not found at ${BACKEND_DIR}" >&2
    echo "Upload code first (see scripts/vps-pack-deploy.ps1 on Windows)." >&2
    exit 1
  fi
}

require_env() {
  if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
    echo "ERROR: ${BACKEND_DIR}/.env missing" >&2
    echo "Run: cp ${BACKEND_DIR}/.env.vps.example ${BACKEND_DIR}/.env && nano ${BACKEND_DIR}/.env" >&2
    exit 1
  fi

  if grep -q 'CHANGE_ME' "${BACKEND_DIR}/.env"; then
    echo "ERROR: Update CHANGE_ME placeholders in ${BACKEND_DIR}/.env" >&2
    exit 1
  fi
}

step_dirs() {
  log "Preparing directories"
  mkdir -p "${BACKEND_DIR}/uploads/images"
  mkdir -p "${APP_DIR}/public"
}

step_schema() {
  local schema_file="${BACKEND_DIR}/src/db/schema.sql"
  if [[ ! -f "${schema_file}" ]]; then
    log "WARN: schema.sql not found, skipping bootstrap"
    return 0
  fi

  log "Bootstrapping database schema (idempotent)"
  sudo -u postgres psql -v ON_ERROR_STOP=0 -d "${DB_NAME}" -f "${schema_file}" || true
}

step_migrations() {
  if [[ -f "${BACKEND_DIR}/run-migrations.js" ]]; then
    log "Running SQL migrations"
    (cd "${BACKEND_DIR}" && node run-migrations.js) || log "WARN: run-migrations.js returned non-zero (may be OK if already applied)"
  fi

  if [[ -f "${BACKEND_DIR}/src/db/migrations/migrate_order_statuses.js" ]]; then
    log "Applying extended order_status enum values"
    (cd "${BACKEND_DIR}" && node src/db/migrations/migrate_order_statuses.js) \
      || log "WARN: migrate_order_statuses.js returned non-zero (may be OK if already applied)"
  fi
}

step_npm() {
  log "Installing npm dependencies"
  cd "${BACKEND_DIR}"
  npm ci --omit=dev
}

step_pm2() {
  log "Starting backend with PM2"
  cd "${BACKEND_DIR}"

  if pm2 describe "${PM2_APP}" >/dev/null 2>&1; then
    pm2 restart ecosystem.config.js --update-env
  else
    pm2 start ecosystem.config.js
  fi

  pm2 save

  if ! pm2 startup systemd -u root --hp /root 2>/dev/null | grep -q 'already'; then
    log "Run the command printed by 'pm2 startup' if this is the first deploy"
    pm2 startup systemd -u root --hp /root || true
  fi
}

step_verify() {
  log "Waiting for backend to listen on :8080"
  local i
  for i in $(seq 1 20); do
    if curl -sf "http://127.0.0.1:8080/" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  echo ""
  echo "=== Phase 2 verification ==="
  pm2 status "${PM2_APP}" || true
  echo -n "Backend root: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8080/" || echo "000"
  echo -n "Via Nginx: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1/" || echo "000"
  echo ""
  echo "Logs: pm2 logs ${PM2_APP} --lines 50"
}

main() {
  require_root
  require_backend
  require_env
  log "Starting Meatvo Phase 2 deploy at ${APP_DIR}"
  step_dirs
  step_schema
  step_npm
  step_migrations
  step_pm2
  step_verify
  log "Phase 2 deploy complete."
  log "Open http://187.127.179.95/ in browser. Set ENFORCE_HTTPS=true after SSL (Phase 3)."
}

main "$@"
