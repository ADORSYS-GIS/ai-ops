#!/bin/bash
set -Eeuo pipefail

#######################################
# Validation helpers
#######################################
fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$1] $2"
}

#######################################
# Required global inputs
#######################################
: "${MODE:?MODE must be set to 'backup' or 'migrate'}"
: "${STORAGE:?STORAGE must be set to 'local' or 's3'}"
: "${SOURCE_DATABASE_URL:?SOURCE_DATABASE_URL not set}"

[[ "$SOURCE_DATABASE_URL" =~ ^(postgresql|postgres):// ]] \
  || fail "SOURCE_DATABASE_URL must start with 'postgresql://' or 'postgres://'"

#######################################
# Mode validation
#######################################
case "$MODE" in
  backup|migrate) ;;
  *) fail "Invalid MODE: $MODE (expected 'backup' or 'migrate')" ;;
esac

#######################################
# Storage validation
#######################################
case "$STORAGE" in
  local)
    : "${BACKUP_DIR:?BACKUP_DIR must be set for local storage}"
    mkdir -p "$BACKUP_DIR"
    DUMP_TARGET_DIR="$BACKUP_DIR"
    ;;
  s3)
    : "${S3_BUCKET:?S3_BUCKET must be set for S3 storage}"
    : "${AWS_REGION:?AWS_REGION must be set for S3 storage}"
    export AWS_DEFAULT_REGION="$AWS_REGION"
    DUMP_TARGET_DIR="$(mktemp -d)"
    ;;
  *)
    fail "Invalid STORAGE: $STORAGE (expected 'local' or 's3')"
    ;;
esac

#######################################
# Pre-flight checks
#######################################
command -v pg_dump >/dev/null || fail "pg_dump not installed"
command -v pg_restore >/dev/null || fail "pg_restore not installed"

if [[ "$STORAGE" == "s3" ]]; then
  command -v aws >/dev/null || fail "AWS CLI required for S3 storage"
fi

#######################################
# Migration-specific validation
#######################################
if [[ "$MODE" == "migrate" ]]; then
  : "${TARGET_DATABASE_URL:?TARGET_DATABASE_URL required for migration}"
  [[ "$TARGET_DATABASE_URL" =~ ^(postgresql|postgres):// ]] \
    || fail "TARGET_DATABASE_URL must start with 'postgresql://' or 'postgres://'"

  [[ "${CONFIRM_MIGRATION:-false}" == "true" ]] \
    || fail "Migration requires CONFIRM_MIGRATION=true"
fi

#######################################
# Cleanup handler
#######################################
cleanup() {
  if [[ "$STORAGE" == "s3" && -n "${DUMP_TARGET_DIR:-}" && -d "$DUMP_TARGET_DIR" ]]; then
    log "INFO" "Cleaning up temporary directory: $DUMP_TARGET_DIR"
    rm -rf "$DUMP_TARGET_DIR"
  fi
}
trap cleanup EXIT

log "INFO" "Script initialized successfully"
