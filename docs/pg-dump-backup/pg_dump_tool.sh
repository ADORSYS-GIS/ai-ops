#!/bin/bash
set -Eeuo pipefail

#######################################
# Global configuration
#######################################
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"
readonly TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
readonly DEFAULT_BACKUP_PREFIX="pg_backup"
readonly DEFAULT_POSTGRES_VERSION="15"

#######################################
# Color codes for output
#######################################
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#######################################
# Logging functions
#######################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

fail() {
    log_error "$1"
    exit 1
}

#######################################
# Helper functions
#######################################
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^postgres(ql)?:// ]]; then
        fail "Database URL must start with 'postgresql://' or 'postgres://'"
    fi
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "Required command '$1' is not installed or not in PATH"
    fi
}

#######################################
# PostgreSQL tool discovery
#######################################
locate_pg_tools() {
    local pg_version="${PG_VERSION:-$DEFAULT_POSTGRES_VERSION}"
    
    # Try to detect PostgreSQL version from source database if not specified
    if [[ -z "${PG_VERSION:-}" ]] && command -v psql >/dev/null 2>&1; then
        if pg_version_detected=$(psql -t -c "SHOW server_version_num;" "$SOURCE_DATABASE_URL" 2>/dev/null | head -1); then
            # Convert version number to major version (e.g., 150003 -> 15)
            pg_version=$((pg_version_detected / 10000))
            log_info "Detected PostgreSQL version $pg_version from source database"
        fi
    fi
    
    # Find pg_dump
    PG_DUMP_BIN=""
    for cand in "pg_dump-${pg_version}" "pg_dump${pg_version}" "pg_dump"; do
        if command -v "$cand" >/dev/null 2>&1; then
            PG_DUMP_BIN="$cand"
            break
        fi
    done
    
    # Find pg_restore
    PG_RESTORE_BIN=""
    for cand in "pg_restore-${pg_version}" "pg_restore${pg_version}" "pg_restore"; do
        if command -v "$cand" >/dev/null 2>&1; then
            PG_RESTORE_BIN="$cand"
            break
        fi
    done
    
    if [[ -z "$PG_DUMP_BIN" ]] || [[ -z "$PG_RESTORE_BIN" ]]; then
        fail "Could not find PostgreSQL tools for version $pg_version"
    fi
    
    log_info "Using PG_DUMP_BIN='$PG_DUMP_BIN', PG_RESTORE_BIN='$PG_RESTORE_BIN'"
}

#######################################
# Database size check
#######################################
get_database_size() {
    local db_url="$1"
    local size_bytes
    
    if size_bytes=$(psql -t -c "SELECT pg_database_size(current_database());" "$db_url" 2>/dev/null); then
        if [[ "$size_bytes" -gt 1073741824 ]]; then # > 1GB
            echo "$((size_bytes / 1073741824)) GB"
        elif [[ "$size_bytes" -gt 1048576 ]]; then # > 1MB
            echo "$((size_bytes / 1048576)) MB"
        elif [[ "$size_bytes" -gt 1024 ]]; then # > 1KB
            echo "$((size_bytes / 1024)) KB"
        else
            echo "${size_bytes} bytes"
        fi
    else
        echo "Unknown"
    fi
}

#######################################
# Pre-flight checks
#######################################
validate_environment() {
    log_info "Validating environment variables..."
    
    # Validate required variables
    : "${MODE:?MODE must be set to 'backup' or 'migrate'}"
    : "${STORAGE:?STORAGE must be set to 'local' or 's3'}"
    : "${SOURCE_DATABASE_URL:?SOURCE_DATABASE_URL must be set}"
    
    validate_url "$SOURCE_DATABASE_URL"
    
    # Validate MODE
    case "$MODE" in
        backup|migrate) ;;
        *) fail "Invalid MODE: $MODE. Must be 'backup' or 'migrate'" ;;
    esac
    
    # Validate STORAGE and set up directories
    case "$STORAGE" in
        local)
            : "${BACKUP_DIR:?BACKUP_DIR must be set for local storage}"
            mkdir -p "$BACKUP_DIR" || fail "Failed to create backup directory: $BACKUP_DIR"
            DUMP_TARGET_DIR="$BACKUP_DIR"
            log_info "Backups will be stored in: $BACKUP_DIR"
            ;;
        s3)
            : "${S3_BUCKET:?S3_BUCKET must be set for S3 storage}"
            : "${AWS_REGION:?AWS_REGION must be set for S3 storage}"
            export AWS_DEFAULT_REGION="$AWS_REGION"
            DUMP_TARGET_DIR="$(mktemp -d)"
            log_info "Using temporary directory: $DUMP_TARGET_DIR"
            ;;
        *)
            fail "Invalid STORAGE: $STORAGE. Must be 'local' or 's3'"
            ;;
    esac
    
    # Migration-specific validation
    if [[ "$MODE" == "migrate" ]]; then
        : "${TARGET_DATABASE_URL:?TARGET_DATABASE_URL must be set for migration}"
        validate_url "$TARGET_DATABASE_URL"
        
        if [[ "${CONFIRM_MIGRATION:-false}" != "true" ]]; then
            fail "Migration requires explicit confirmation. Set CONFIRM_MIGRATION=true"
        fi
    fi
    
    # Check for required commands
    locate_pg_tools
    check_command "$PG_DUMP_BIN"
    check_command "$PG_RESTORE_BIN"
    
    if [[ "$STORAGE" == "s3" ]]; then
        check_command "aws"
        
        # Verify AWS credentials and bucket access
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            fail "AWS credentials not configured or invalid"
        fi
        
        if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
            log_warning "Cannot access S3 bucket: $S3_BUCKET. Ensure it exists and you have proper permissions."
        fi
    fi
    
    log_success "Environment validation passed"
}

#######################################
# Backup function
#######################################
perform_backup() {
    local source_db="$1"
    local output_file="$2"
    
    log_info "Starting backup from source database"
    log_info "Database size: $(get_database_size "$source_db")"
    
    # Build pg_dump command with optional extra arguments
    local dump_cmd=(
        "$PG_DUMP_BIN"
        --no-password
        --verbose
        --format=custom
        --compress=9
        --dbname="$source_db"
        --file="$output_file"
    )
    
    # Add parallel dump if supported and configured
    if [[ -n "${PG_DUMP_JOBS:-}" ]] && [[ "$PG_DUMP_JOBS" -gt 1 ]]; then
        dump_cmd+=(--jobs="$PG_DUMP_JOBS")
    fi
    
    # Add extra options if provided
    if [[ -n "${PG_DUMP_EXTRA_OPTS:-}" ]]; then
        # Split into array to preserve quoting
        eval "dump_cmd+=($PG_DUMP_EXTRA_OPTS)"
    fi
    
    log_info "Running: ${dump_cmd[*]}"
    
    # Execute the backup
    if "${dump_cmd[@]}"; then
        if [[ -s "$output_file" ]]; then
            local file_size=$(du -h "$output_file" | cut -f1)
            log_success "Backup completed successfully: $output_file (Size: $file_size)"
        else
            fail "Backup completed but dump file is empty: $output_file"
        fi
    else
        fail "Backup failed with exit code $?"
    fi
}

#######################################
# Restore function
#######################################
perform_restore() {
    local target_db="$1"
    local dump_file="$2"
    
    log_info "Starting restore to target database"
    
    # Build pg_restore command
    local restore_cmd=(
        "$PG_RESTORE_BIN"
        --no-password
        --verbose
        --clean
        --if-exists
        --dbname="$target_db"
    )
    
    # Add parallel restore if supported and configured
    if [[ -n "${PG_RESTORE_JOBS:-}" ]] && [[ "$PG_RESTORE_JOBS" -gt 1 ]]; then
        restore_cmd+=(--jobs="$PG_RESTORE_JOBS")
    fi
    
    # Add extra options if provided
    if [[ -n "${PG_RESTORE_EXTRA_OPTS:-}" ]]; then
        eval "restore_cmd+=($PG_RESTORE_EXTRA_OPTS)"
    fi
    
    restore_cmd+=("$dump_file")
    
    log_info "Running: ${restore_cmd[*]}"
    
    # Execute the restore
    if "${restore_cmd[@]}"; then
        log_success "Restore completed successfully"
    else
        fail "Restore failed with exit code $?"
    fi
}

#######################################
# S3 Upload function
#######################################
upload_to_s3() {
    local file_path="$1"
    local filename="$(basename "$file_path")"
    
    # Normalize S3 prefix
    local prefix="${S3_PREFIX:-}"
    if [[ -n "$prefix" ]] && [[ "${prefix: -1}" != "/" ]]; then
        prefix="$prefix/"
    fi
    
    local s3_path="s3://${S3_BUCKET}/${prefix}${filename}"
    
    log_info "Uploading backup to S3: $s3_path"
    
    # Upload with multipart for large files
    local aws_cmd=(
        aws s3 cp
        "$file_path"
        "$s3_path"
        --quiet
    )
    
    # Add storage class if specified
    if [[ -n "${S3_STORAGE_CLASS:-}" ]]; then
        aws_cmd+=(--storage-class "$S3_STORAGE_CLASS")
    fi
    
    # Execute upload
    if "${aws_cmd[@]}"; then
        log_success "Upload completed: $s3_path"
        
        # Set retention policy if specified
        if [[ -n "${S3_RETENTION_DAYS:-}" ]]; then
            aws s3api put-object-retention \
                --bucket "$S3_BUCKET" \
                --key "${prefix}${filename}" \
                --retention '{"Mode":"GOVERNANCE","RetainUntilDate":'$(date -d "+${S3_RETENTION_DAYS} days" +%Y-%m-%dT%H:%M:%SZ)'}' \
                --quiet && \
            log_info "Set S3 retention policy: ${S3_RETENTION_DAYS} days"
        fi
    else
        fail "Failed to upload to S3"
    fi
}

#######################################
# Cleanup handler
#######################################
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code"
        
        # Clean up incomplete dump file
        if [[ -n "${DUMP_FILE:-}" ]] && [[ -f "$DUMP_FILE" ]]; then
            log_warning "Removing incomplete dump file: $DUMP_FILE"
            rm -f "$DUMP_FILE"
        fi
    fi
    
    # Clean up temporary directory for S3
    if [[ "$STORAGE" == "s3" ]] && [[ -n "${DUMP_TARGET_DIR:-}" ]] && [[ -d "$DUMP_TARGET_DIR" ]]; then
        log_info "Cleaning up temporary directory: $DUMP_TARGET_DIR"
        rm -rf "$DUMP_TARGET_DIR"
    fi
    
    # Exit with original exit code
    exit $exit_code
}

# Set trap for cleanup
trap cleanup ERR EXIT INT TERM

#######################################
# Main execution
#######################################
main() {
    log_info "Starting PostgreSQL Backup/Migration Script v$SCRIPT_VERSION"
    
    # Step 1: Validate environment
    validate_environment
    
    # Step 2: Create dump file path
    local backup_prefix="${BACKUP_PREFIX:-$DEFAULT_BACKUP_PREFIX}"
    DUMP_FILE="${DUMP_TARGET_DIR}/${backup_prefix}_${TIMESTAMP}.dump"
    
    # Step 3: Perform backup
    perform_backup "$SOURCE_DATABASE_URL" "$DUMP_FILE"
    
    # Step 4: Perform migration if requested
    if [[ "$MODE" == "migrate" ]]; then
        log_info "Mode: MIGRATE (source → target)"
        perform_restore "$TARGET_DATABASE_URL" "$DUMP_FILE"
    else
        log_info "Mode: BACKUP (source only)"
    fi
    
    # Step 5: Handle storage
    case "$STORAGE" in
        s3)
            upload_to_s3 "$DUMP_FILE"
            # Remove local temp file after successful upload
            if [[ -f "$DUMP_FILE" ]]; then
                rm -f "$DUMP_FILE"
                log_info "Removed local temporary backup file"
            fi
            ;;
        local)
            log_success "Backup stored locally at: $DUMP_FILE"
            # Optional: Clean up old backups
            if [[ -n "${LOCAL_RETENTION_DAYS:-}" ]]; then
                log_info "Cleaning up backups older than $LOCAL_RETENTION_DAYS days..."
                find "$BACKUP_DIR" -name "${backup_prefix}_*.dump" -mtime +$LOCAL_RETENTION_DAYS -delete 2>/dev/null || true
            fi
            ;;
    esac
    
    log_success "Operation completed successfully"
}

# Run main function
main "$@"