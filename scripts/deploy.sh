#!/usr/bin/env bash
# Meatvo production deploy — pull, build, migrate, restart, verify
# Run on VPS as root from /opt/meatvo:
#   bash scripts/deploy.sh
#
# Options:
#   SKIP_GIT=1       Skip git pull (tarball deploy)
#   SKIP_MIGRATE=1   Skip database migrations
#   APP_DIR=/opt/meatvo

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meatvo}"
BACKEND_DIR="${APP_DIR}/backend"
PM2_APP="meatvo-backend"
DB_NAME="${MEATVO_DB_NAME:-meatvo_db}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_backend() {
  if [[ ! -f "${BACKEND_DIR}/package.json" ]]; then
    echo "ERROR: Backend not found at ${BACKEND_DIR}" >&2
    exit 1
  fi
}

require_env() {
  if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
    echo "ERROR: ${BACKEND_DIR}/.env missing" >&2
    exit 1
  fi
}

step_pull() {
  if [[ "${SKIP_GIT:-0}" == "1" ]]; then
    log "Skipping git pull (SKIP_GIT=1)"
    return
  fi
  if [[ -d "${APP_DIR}/.git" ]]; then
    log "Pulling latest code"
    cd "${APP_DIR}"
    git pull --ff-only
  else
    log "No git repo at ${APP_DIR} — skipping pull"
  fi
}

step_backup() {
  local backup_script="${APP_DIR}/scripts/backup/postgres-backup.sh"
  if [[ -x "${backup_script}" ]]; then
    log "Pre-deploy database backup"
    bash "${backup_script}" || log "WARN: backup failed (continuing)"
  fi
}

step_schema_only() {
  if [[ "${SKIP_MIGRATE:-0}" == "1" ]]; then
    return
  fi

  local schema_file="${BACKEND_DIR}/src/db/schema.sql"
  if [[ -f "${schema_file}" ]]; then
    log "Applying schema bootstrap (idempotent)"
    sudo -u postgres psql -v ON_ERROR_STOP=0 -d "${DB_NAME}" -f "${schema_file}" || true
  fi
}

step_node_migrations() {
  if [[ "${SKIP_MIGRATE:-0}" == "1" ]]; then
    log "Skipping node migrations (SKIP_MIGRATE=1)"
    return
  fi

  if [[ -f "${BACKEND_DIR}/run-migrations.js" ]]; then
    log "Running SQL migrations"
    (cd "${BACKEND_DIR}" && node run-migrations.js) || log "WARN: migrations returned non-zero"
  fi

  if [[ -f "${BACKEND_DIR}/src/db/migrations/migrate_order_statuses.js" ]]; then
    log "Applying extended order_status enum"
    (cd "${BACKEND_DIR}" && node src/db/migrations/migrate_order_statuses.js) || true
  fi
}

step_install() {
  log "Installing dependencies"
  cd "${BACKEND_DIR}"
  npm ci --omit=dev --ignore-scripts
}

step_pm2() {
  log "Restarting PM2"
  cd "${BACKEND_DIR}"
  mkdir -p logs uploads/images

  if pm2 describe "${PM2_APP}" >/dev/null 2>&1; then
    pm2 restart ecosystem.config.js --env production --update-env
  else
    pm2 start ecosystem.config.js --env production
  fi
  pm2 save
}

step_health() {
  log "Waiting for health checks"
  local i
  for i in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:8080/health/live" >/dev/null 2>&1; then
      log "Liveness OK"
      break
    fi
    sleep 1
  done

  echo ""
  echo "=== Deploy verification ==="
  pm2 status "${PM2_APP}" || true
  echo -n "/health/live: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8080/health/live" || echo "000"
  echo -n "/health/ready: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8080/health/ready" || echo "000"
  echo -n "Via Nginx: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1/" || echo "000"
  echo ""
}

main() {
  require_backend
  require_env
  log "Starting Meatvo deploy at ${APP_DIR}"
  step_pull
  step_backup
  step_schema_only
  step_install
  step_node_migrations
  step_pm2
  step_health
  log "Deploy complete."
}

main "$@"
