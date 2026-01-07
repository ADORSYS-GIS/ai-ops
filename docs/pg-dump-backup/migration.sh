#!/bin/bash
set -euo pipefail

: "${SOURCE_DATABASE_URL:?SOURCE_DATABASE_URL not set}"
: "${TARGET_DATABASE_URL:?TARGET_DATABASE_URL not set}"

DUMP_FILE="migration_$(date -u +%Y%m%dT%H%M%SZ).dump"

trap 'rm -f "$DUMP_FILE"; echo "[ERROR] Migration failed at line $LINENO"' ERR

echo "[1/3] Dumping source database..."
pg_dump \
  --no-password \
  --dbname="$SOURCE_DATABASE_URL" \
  --format=custom \
  --file="$DUMP_FILE"

echo "[2/3] Restoring into target database..."
pg_restore \
  --no-password \
  --dbname="$TARGET_DATABASE_URL" \
  --clean \
  --if-exists \
  "$DUMP_FILE"

echo "[3/3] Migration completed successfully"

# Optional: remove dump after successful migration
rm -f "$DUMP_FILE"
