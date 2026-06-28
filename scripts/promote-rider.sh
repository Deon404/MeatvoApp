#!/usr/bin/env bash
# Promote a user to delivery partner (rider) on VPS.
#
# Usage:
#   bash scripts/promote-rider.sh 9876543210
#   bash scripts/promote-rider.sh --id 42
#
# Run from repo root on the server (/opt/meatvo).

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meatvo}"
BACKEND_DIR="${APP_DIR}/backend"
API_CONTAINER="${MEATVO_API_CONTAINER:-meatvo-api}"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/promote-rider.sh <phone>" >&2
  echo "       bash scripts/promote-rider.sh --id <user_id>" >&2
  exit 1
fi

if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${API_CONTAINER}"; then
  exec docker exec "${API_CONTAINER}" node scripts/promote-rider.js "$@"
fi

if [[ ! -f "${BACKEND_DIR}/scripts/promote-rider.js" ]]; then
  echo "ERROR: ${BACKEND_DIR}/scripts/promote-rider.js not found" >&2
  echo "Set APP_DIR or deploy backend to /opt/meatvo first." >&2
  exit 1
fi

cd "${BACKEND_DIR}"
exec node scripts/promote-rider.js "$@"
