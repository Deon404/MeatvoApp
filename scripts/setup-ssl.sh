#!/usr/bin/env bash
# SSL setup wrapper — delegates to vps-phase3-ssl.sh
# Usage:
#   MEATVO_DOMAIN=yourdomain.com MEATVO_API_DOMAIN=api.yourdomain.com \
#     bash scripts/setup-ssl.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${MEATVO_DOMAIN:-}" ]]; then
  echo "ERROR: Set MEATVO_DOMAIN (e.g. meatvo.com)" >&2
  exit 1
fi

exec bash "${SCRIPT_DIR}/vps-phase3-ssl.sh" "$@"
