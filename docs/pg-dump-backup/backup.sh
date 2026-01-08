#!/bin/bash
# ----------------------------------------------------------------------------
# PostgreSQL Backup Script
# 
# Purpose: Creates a compressed custom-format backup of a PostgreSQL database
#          using DATABASE_URL and saves it to a specified directory.
#
# Usage: 
#   Set environment variables:
#     export DATABASE_URL="postgres://user:pass@host:port/dbname"
#     export BACKUP_DIR="/path/to/backups"
#   Then run: ./backup.sh
#
# Requirements:
#   - pg_dump must be installed
#   - DATABASE_URL must include username, password, host, and database name
#   - Write permissions to BACKUP_DIR
#
# Output:
#   Creates a .dump file named like: dbname_YYYYMMDDTHHMMSSZ.dump.gz
#   Example: myapp_20260107T100000Z.dump.gz
# ----------------------------------------------------------------------------

set -euo pipefail

trap 'echo "[ERROR] Backup failed at line $LINENO"; exit 1' ERR

: "${DATABASE_URL:?DATABASE_URL not set}"
: "${BACKUP_DIR:?BACKUP_DIR not set}"

# Check if pg_dump is available
if ! command -v pg_dump &> /dev/null; then
  echo "[ERROR] pg_dump command not found. Installing postgresql-client..."
  if ! sudo apt install -y postgresql-client; then
    echo "[ERROR] Failed to install postgresql-client. Please install manually."
    exit 1
  fi
  # Verify installation
  if ! command -v pg_dump &> /dev/null; then
    echo "[ERROR] pg_dump is still not available after installation."
    exit 1
  fi
fi   

export PGCONNECT_TIMEOUT=10

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
DB_NAME=$(basename "$(echo "$DATABASE_URL" | sed 's/[?].*//')")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

mkdir -p "$BACKUP_DIR"

echo "[INFO] Starting backup at $TIMESTAMP"

pg_dump \
  --no-password \
  --dbname="$DATABASE_URL" \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_FILE"

echo "[INFO] Backup completed: $BACKUP_FILE"   