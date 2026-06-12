#!/usr/bin/env bash
# Meatvo VPS Phase 1 — quick health check (no installs)
# Run as root: bash vps-phase1-verify.sh

set -euo pipefail

MEATVO_DB_NAME="${MEATVO_DB_NAME:-meatvo_db}"
PASS=0
FAIL=0

ok() {
  echo "  OK   $*"
  PASS=$((PASS + 1))
}

bad() {
  echo "  FAIL $*" >&2
  FAIL=$((FAIL + 1))
}

check_command() {
  local name="$1"
  local cmd="$2"
  if eval "${cmd}" >/dev/null 2>&1; then
    ok "${name}"
  else
    bad "${name}"
  fi
}

echo "=== Meatvo VPS Phase 1 Verification ==="

if command -v node >/dev/null 2>&1; then
  node_ver="$(node --version)"
  if [[ "${node_ver}" == v20.* ]]; then
    ok "Node.js ${node_ver}"
  else
    bad "Node.js version is ${node_ver} (expected v20.x)"
  fi
else
  bad "Node.js not installed"
fi

if command -v npm >/dev/null 2>&1; then
  ok "npm $(npm --version)"
else
  bad "npm not installed"
fi

if command -v pm2 >/dev/null 2>&1; then
  ok "pm2 $(pm2 --version)"
else
  bad "pm2 not installed"
fi

if sudo -u postgres psql -c "\l" 2>/dev/null | grep -q "${MEATVO_DB_NAME}"; then
  ok "PostgreSQL database ${MEATVO_DB_NAME} exists"
else
  bad "PostgreSQL database ${MEATVO_DB_NAME} not found"
fi

redis_ping="$(redis-cli ping 2>/dev/null || true)"
if [[ "${redis_ping}" == "PONG" ]]; then
  ok "Redis PONG"
else
  bad "Redis ping (got: ${redis_ping:-none})"
fi

for svc in nginx postgresql redis-server; do
  if systemctl is-active --quiet "${svc}"; then
    ok "service ${svc} active"
  else
    bad "service ${svc} not active"
  fi
done

if [[ -f /etc/nginx/sites-enabled/meatvo ]]; then
  ok "Nginx meatvo site enabled"
else
  bad "Nginx meatvo site missing"
fi

if nginx -t >/dev/null 2>&1; then
  ok "nginx -t config valid"
else
  bad "nginx -t failed"
fi

http_code="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ 2>/dev/null || echo '000')"
if [[ "${http_code}" == "502" || "${http_code}" == "503" || "${http_code}" == "200" ]]; then
  ok "Nginx HTTP response ${http_code} (502/503 expected before backend deploy)"
else
  bad "Unexpected Nginx HTTP response: ${http_code}"
fi

if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q "Status: active"; then
    ok "UFW active"
  else
    bad "UFW not active"
  fi

  for port in 22 80 443 8080; do
    if ufw status | grep -q "${port}"; then
      ok "UFW allows port ${port}"
    else
      bad "UFW missing rule for port ${port}"
    fi
  done
else
  bad "ufw not installed"
fi

echo ""
echo "Result: ${PASS} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi

echo "Phase 1 looks good. Deploy backend in Phase 2 to clear Nginx 502."
