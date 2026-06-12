#!/usr/bin/env bash
# Meatvo VPS Phase 3 — SSL/TLS with Certbot
# Run as root after Phase 2 backend is live on port 8080.
#
# Usage:
#   MEATVO_DOMAIN=yourdomain.com MEATVO_API_DOMAIN=api.yourdomain.com \
#     bash scripts/vps-phase3-ssl.sh

set -euo pipefail

MEATVO_DOMAIN="${MEATVO_DOMAIN:-}"
MEATVO_API_DOMAIN="${MEATVO_API_DOMAIN:-}"
NGINX_SITE="/etc/nginx/sites-available/meatvo"
BACKEND_ENV="/opt/meatvo/backend/.env"

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

install_certbot() {
  log "Installing Certbot"
  if ! command -v certbot >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y certbot python3-certbot-nginx
  fi
}

prepare_nginx_acme() {
  log "Preparing Nginx for ACME challenge"
  cat > "${NGINX_SITE}" <<EOF
server {
    listen 80;
    server_name ${MEATVO_DOMAIN} www.${MEATVO_DOMAIN} ${MEATVO_API_DOMAIN};

    client_max_body_size 10M;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF
  mkdir -p /var/www/certbot
  ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/meatvo
  nginx -t
  systemctl reload nginx
}

obtain_certificate() {
  log "Obtaining SSL certificate for ${MEATVO_DOMAIN}"
  local domains=(-d "${MEATVO_DOMAIN}" -d "www.${MEATVO_DOMAIN}")
  if [[ -n "${MEATVO_API_DOMAIN}" ]]; then
    domains+=(-d "${MEATVO_API_DOMAIN}")
  fi
  certbot --nginx "${domains[@]}" --non-interactive --agree-tos --register-unsafely-without-email --redirect
}

update_backend_env() {
  if [[ ! -f "${BACKEND_ENV}" ]]; then
    log "WARN: ${BACKEND_ENV} not found — update PHONEPE_* and CORS manually"
    return
  fi

  local base_url="https://${MEATVO_DOMAIN}"
  local api_url="https://${MEATVO_API_DOMAIN:-${MEATVO_DOMAIN}}"

  sed -i "s|^ENFORCE_HTTPS=.*|ENFORCE_HTTPS=true|" "${BACKEND_ENV}" || true
  grep -q '^ENFORCE_HTTPS=' "${BACKEND_ENV}" || echo 'ENFORCE_HTTPS=true' >> "${BACKEND_ENV}"

  if grep -q '^PHONEPE_REDIRECT_URL=' "${BACKEND_ENV}"; then
    sed -i "s|^PHONEPE_REDIRECT_URL=.*|PHONEPE_REDIRECT_URL=${base_url}/payment/return|" "${BACKEND_ENV}"
  fi
  if grep -q '^PHONEPE_WEBHOOK_URL=' "${BACKEND_ENV}"; then
    sed -i "s|^PHONEPE_WEBHOOK_URL=.*|PHONEPE_WEBHOOK_URL=${api_url}/api/payments/phonepe/webhook|" "${BACKEND_ENV}"
  fi
  if grep -q '^CORS_ORIGINS=' "${BACKEND_ENV}"; then
    sed -i "s|^CORS_ORIGINS=.*|CORS_ORIGINS=${base_url},https://www.${MEATVO_DOMAIN}|" "${BACKEND_ENV}"
  fi

  log "Backend .env updated for HTTPS"
  if command -v pm2 >/dev/null 2>&1; then
    pm2 restart meatvo-backend || true
  fi
}

verify_ssl() {
  log "Verifying SSL"
  certbot renew --dry-run
  curl -sI "https://${MEATVO_DOMAIN}/health" | head -5 || true
}

main() {
  require_root
  require_domain
  install_certbot
  prepare_nginx_acme
  obtain_certificate
  update_backend_env
  verify_ssl
  log "Phase 3 SSL setup complete."
}

main "$@"
