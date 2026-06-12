#!/usr/bin/env bash
# Daily PostgreSQL backup for Meatvo VPS
# Cron: 0 2 * * * /opt/meatvo/scripts/backup/postgres-backup.sh

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/meatvo/backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DB_NAME="${DB_NAME:-meatvo_db}"
DB_USER="${DB_USER:-meatvo_user}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

mkdir -p "${BACKUP_DIR}"

pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -mtime +"${RETENTION_DAYS}" -delete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup saved: ${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
