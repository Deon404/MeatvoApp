#!/usr/bin/env bash
# Install Meatvo Nginx site config with landing + API routing.
# Run on VPS as root after SSL certs exist (Phase 3) or for config refresh.
#
# Usage:
#   MEATVO_DOMAIN=meatvo.com bash scripts/vps-install-nginx.sh
#
# Optional:
#   MEATVO_API_DOMAIN=api.meatvo.com   # included in server_name if set
#   APP_DIR=/opt/meatvo
#   SKIP_RELOAD=1                      # only write configs, do not reload nginx

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meatvo}"
MEATVO_DOMAIN="${MEATVO_DOMAIN:-}"
MEATVO_API_DOMAIN="${MEATVO_API_DOMAIN:-}"
NGINX_SITE="/etc/nginx/sites-available/meatvo"
SNIPPET_DEST="/etc/nginx/snippets/meatvo-proxy.conf"
LANDING_DIR="/var/www/meatvo-landing"
TEMPLATE="${APP_DIR}/scripts/nginx-meatvo.conf"
SNIPPET_SRC="${APP_DIR}/scripts/nginx-meatvo-proxy.conf"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: Run as root" >&2
    exit 1
  fi
}

require_domain() {
  if [[ -z "${MEATVO_DOMAIN}" ]]; then
    echo "ERROR: Set MEATVO_DOMAIN (e.g. meatvo.com)" >&2
    exit 1
  fi
}

require_files() {
  if [[ ! -f "${TEMPLATE}" ]]; then
    echo "ERROR: Missing ${TEMPLATE}" >&2
    exit 1
  fi
  if [[ ! -f "${SNIPPET_SRC}" ]]; then
    echo "ERROR: Missing ${SNIPPET_SRC}" >&2
    exit 1
  fi
}

step_landing() {
  # shellcheck source=scripts/lib/sync-landing.sh
  source "${APP_DIR}/scripts/lib/sync-landing.sh"
  meatvo_sync_landing
}

step_snippet() {
  log "Installing proxy snippet at ${SNIPPET_DEST}"
  mkdir -p "$(dirname "${SNIPPET_DEST}")"
  cp "${SNIPPET_SRC}" "${SNIPPET_DEST}"
}

step_nginx_site() {
  log "Installing Nginx site for ${MEATVO_DOMAIN}"

  sed "s/YOUR_DOMAIN/${MEATVO_DOMAIN}/g" "${TEMPLATE}" > "${NGINX_SITE}"

  ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/meatvo
  rm -f /etc/nginx/sites-enabled/default
}

step_reload() {
  if [[ "${SKIP_RELOAD:-0}" == "1" ]]; then
    log "SKIP_RELOAD=1 — not reloading nginx"
    return
  fi
  nginx -t
  systemctl reload nginx
  log "Nginx reloaded"
}

main() {
  require_root
  require_domain
  require_files
  step_landing
  step_snippet
  step_nginx_site
  step_reload
  log "Nginx install complete."
  log "Landing: https://${MEATVO_DOMAIN}/"
  log "API:     https://${MEATVO_DOMAIN}/api/"
}

main "$@"
