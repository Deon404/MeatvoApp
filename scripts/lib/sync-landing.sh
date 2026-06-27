#!/usr/bin/env bash
# Sync marketing landing static files to /var/www/meatvo-landing
# Sourced by vps-phase2-deploy.sh, deploy.sh, and vps-install-nginx.sh

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meatvo}"
LANDING_SRC="${APP_DIR}/landing"
LANDING_DIR="${LANDING_DIR:-/var/www/meatvo-landing}"

meatvo_sync_landing() {
  if [[ ! -d "${LANDING_SRC}" ]]; then
    echo "[landing] WARN: ${LANDING_SRC} not found — skipping"
    return 0
  fi

  echo "[landing] Syncing ${LANDING_SRC} → ${LANDING_DIR}"
  mkdir -p "${LANDING_DIR}"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${LANDING_SRC}/" "${LANDING_DIR}/"
  else
    find "${LANDING_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -a "${LANDING_SRC}/." "${LANDING_DIR}/"
  fi

  if id www-data >/dev/null 2>&1; then
    chown -R www-data:www-data "${LANDING_DIR}"
  elif id nginx >/dev/null 2>&1; then
    chown -R nginx:nginx "${LANDING_DIR}"
  fi
}
