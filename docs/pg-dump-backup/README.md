# Migration Script: migration.sh

This script performs a complete PostgreSQL database migration using `pg_dump` and `pg_restore`. It safely exports data from a source database and imports it into a target database, with automatic cleanup on failure.

## Prerequisites

- PostgreSQL client tools (`pg_dump`, `pg_restore`) installed
- Access to both source and target databases
- Environment variables set for database connections

### Installation

On Debian/Ubuntu systems, install the PostgreSQL client:

```bash
sudo apt update
sudo apt install -y postgresql-client
```

On other systems, use your package manager (e.g., `yum install postgresql-client` on RHEL/CentOS, or download from PostgreSQL website).

## Environment Variables

Set these before running the script:

- `SOURCE_DATABASE_URL`: Connection string for the source database (e.g., `postgres://user:password@host:5432/sourcedb`)
- `TARGET_DATABASE_URL`: Connection string for the target database (e.g., `postgres://user:password@host:5432/targetdb`)

## Usage

1. Make the script executable:

   ```bash
   chmod +x migration.sh
   ```

2. Set environment variables and run:
   ```bash
   export SOURCE_DATABASE_URL="postgres://user:pass@source.host:5432/db"
   export TARGET_DATABASE_URL="postgres://user:pass@target.host:5432/db"
   ./migration.sh
   ```

## What It Does

1. **Dumps the source database** to a timestamped file using custom format
2. **Restores to the target database** with `--clean` (drops existing objects) and `--if-exists` (safe if objects missing)
3. **Cleans up** the dump file on success or failure

## Example Output

```
[1/3] Dumping source database...
[2/3] Restoring into target database...
[3/3] Migration completed successfully
```

## Error Handling

- Fails fast on any error (`set -euo pipefail`)
- Cleans up temporary files automatically
- Shows error line number on failure

## Notes

- Target database will be overwritten
- Ensure extensions are installed on target if used
- For large databases, monitor disk space
