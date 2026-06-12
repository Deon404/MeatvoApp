#!/usr/bin/env bash
# Meatvo VPS Phase 1 — Hostinger KVM basic setup
# Run as root on Ubuntu 22.04/24.04:
#   MEATVO_DB_PASSWORD='...' MEATVO_REDIS_PASSWORD='...' bash vps-phase1-setup.sh

set -euo pipefail

MEATVO_DB_NAME="${MEATVO_DB_NAME:-meatvo_db}"
MEATVO_DB_USER="${MEATVO_DB_USER:-meatvo_user}"
NGINX_SITE="/etc/nginx/sites-available/meatvo"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: Run as root (e.g. ssh root@YOUR_SERVER_IP)" >&2
    exit 1
  fi
}

require_db_password() {
  if [[ -z "${MEATVO_DB_PASSWORD:-}" ]]; then
    echo "ERROR: Set MEATVO_DB_PASSWORD before running this script." >&2
    echo "Example: MEATVO_DB_PASSWORD='YourStrongPassword' bash $0" >&2
    exit 1
  fi
}

step_system_update() {
  log "Step 1/7 — System update"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
}

step_install_tools() {
  log "Step 2/7 — Installing required tools"
  apt-get install -y curl wget git ufw nano htop unzip ca-certificates gnupg
}

step_configure_firewall() {
  log "Step 3/7 — Configuring UFW firewall"
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  # Port 8080 is NOT exposed — Nginx proxies to localhost:8080
  ufw --force enable
  ufw status verbose || ufw status
}

step_install_node() {
  log "Step 4/7 — Installing Node.js 20 and PM2"
  if command -v node >/dev/null 2>&1; then
    local current_major
    current_major="$(node -p "process.versions.node.split('.')[0]")"
    if [[ "${current_major}" == "20" ]]; then
      log "Node.js 20 already installed: $(node --version)"
    else
      log "Node.js $(node --version) found; installing Node.js 20 from NodeSource"
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs
    fi
  else
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi

  if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2
  else
    log "PM2 already installed: $(pm2 --version)"
  fi

  log "Node: $(node --version) | npm: $(npm --version) | pm2: $(pm2 --version)"
}

step_install_postgresql() {
  log "Step 5/7 — Installing PostgreSQL and creating database"
  apt-get install -y postgresql postgresql-contrib
  systemctl start postgresql
  systemctl enable postgresql

  # Escape single quotes in password for use inside SQL string literal
  local escaped_password
  escaped_password="${MEATVO_DB_PASSWORD//\'/\'\'}"

  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${MEATVO_DB_NAME}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${MEATVO_DB_NAME};"
  fi

  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${MEATVO_DB_USER}'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE USER ${MEATVO_DB_USER} WITH PASSWORD '${escaped_password}';"
  else
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER USER ${MEATVO_DB_USER} WITH PASSWORD '${escaped_password}';"
  fi

  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "GRANT ALL PRIVILEGES ON DATABASE ${MEATVO_DB_NAME} TO ${MEATVO_DB_USER};"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER USER ${MEATVO_DB_USER} CREATEDB;"

  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${MEATVO_DB_NAME}" <<EOF
GRANT ALL ON SCHEMA public TO ${MEATVO_DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${MEATVO_DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${MEATVO_DB_USER};
EOF

  log "PostgreSQL database '${MEATVO_DB_NAME}' and user '${MEATVO_DB_USER}' ready"
}

step_install_redis() {
  log "Step 6/7 — Installing and configuring Redis"
  apt-get install -y redis-server

  if [[ -z "${MEATVO_REDIS_PASSWORD:-}" ]]; then
    echo "ERROR: Set MEATVO_REDIS_PASSWORD before running this script." >&2
    exit 1
  fi

  local redis_conf="/etc/redis/redis.conf"
  if [[ -f "${redis_conf}" ]]; then
    sed -i 's/^supervised no/supervised systemd/' "${redis_conf}"
    sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' "${redis_conf}"
    if ! grep -q '^maxmemory-policy allkeys-lru' "${redis_conf}"; then
      echo 'maxmemory-policy allkeys-lru' >> "${redis_conf}"
    fi
    if grep -q '^requirepass' "${redis_conf}"; then
      sed -i "s/^requirepass .*/requirepass ${MEATVO_REDIS_PASSWORD}/" "${redis_conf}"
    else
      echo "requirepass ${MEATVO_REDIS_PASSWORD}" >> "${redis_conf}"
    fi
    sed -i 's/^bind .*/bind 127.0.0.1 ::1/' "${redis_conf}" 2>/dev/null || true
  fi

  systemctl restart redis-server
  systemctl enable redis-server

  local ping_result
  ping_result="$(redis-cli -a "${MEATVO_REDIS_PASSWORD}" ping 2>/dev/null | tail -1)"
  if [[ "${ping_result}" != "PONG" ]]; then
    echo "ERROR: Redis ping failed (got: ${ping_result})" >&2
    exit 1
  fi
  log "Redis OK: ${ping_result}"
}

step_install_nginx() {
  log "Step 7/7 — Installing and configuring Nginx reverse proxy"
  apt-get install -y nginx
  systemctl start nginx
  systemctl enable nginx

  cat > "${NGINX_SITE}" <<'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF

  ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/meatvo
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
  log "Nginx configured and reloaded"
}

run_verification() {
  log "Running post-setup verification"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -x "${script_dir}/vps-phase1-verify.sh" ]]; then
    bash "${script_dir}/vps-phase1-verify.sh"
  else
    bash - <<'VERIFY'
set -euo pipefail
echo "Node: $(node --version)"
echo "npm: $(npm --version)"
echo "pm2: $(pm2 --version)"
sudo -u postgres psql -c "\l" | grep meatvo || true
redis-cli ping
systemctl is-active nginx
systemctl is-active postgresql
systemctl is-active redis-server
curl -s -o /dev/null -w "HTTP via Nginx: %{http_code}\n" http://127.0.0.1/ || true
ufw status | head -20
VERIFY
  fi
}

main() {
  require_root
  require_db_password

  log "Starting Meatvo VPS Phase 1 setup"
  step_system_update
  step_install_tools
  step_configure_firewall
  step_install_node
  step_install_postgresql
  step_install_redis
  step_install_nginx
  run_verification

  log "Phase 1 setup complete."
  log "Next (Phase 2): deploy backend, set TRUST_PROXY=true, DATABASE_URL=postgresql://${MEATVO_DB_USER}:****@127.0.0.1:5432/${MEATVO_DB_NAME}"
  log "Note: HTTP 502 from Nginx is expected until the Node backend is running on port 8080."
}

main "$@"
