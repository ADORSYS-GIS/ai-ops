# PostgreSQL Backup & Migration Tool

A production-ready shell script for PostgreSQL database backup and migration operations. This tool provides robust, non-interactive backup and migration capabilities with support for multiple storage backends.

## ✨ Features

- **Dual Modes**: Backup-only or backup-with-migration operations
- **Multiple Storage Backends**: Local filesystem or AWS S3
- **Production Safe**: Non-interactive operation with comprehensive error handling
- **Version Aware**: Auto-detects PostgreSQL version and uses appropriate tools

## 🐳 Quick Test with Docker

### Prerequisites

- **PostgreSQL Client Tools** (`pg_dump`, `pg_restore`, `psql`): Required to run the script. Install if not present:

  ```bash
  # Ubuntu/Debian
  sudo apt-get update && sudo apt-get install -y postgresql-client

  # macOS (Homebrew)
  brew install libpq && brew link --force libpq

  # RHEL/CentOS/Fedora
  sudo dnf install -y postgresql

  # Alpine
  apk add --no-cache postgresql-client
  ```

- Install Docker: [Docker Installation Guide](https://docs.docker.com/get-docker/)
- Download the script:

```bash
git clone https://github.com/ADORSYS-GIS/ai-ops.git
cd ai-ops/docs/pg-dump-backup
chmod +x pg_dump_tool.sh
```

- prepare .pgpass env file

```bash
echo "localhost:5432:testdb:testuser:testpass" > $HOME/.pgpass && chmod 600 $HOME/.pgpass
```

### Step 1: Start PostgreSQL Container

Detect your local PostgreSQL client version and start a matching Docker container:

> 💡 **Automatic Version Matching:** The commands below automatically detect your local `pg_dump` version and start a matching PostgreSQL Docker container. This ensures compatibility between your local tools and the database server.

```bash
# Detect your local pg_dump version
if ! command -v pg_dump &> /dev/null; then
    echo "ERROR: pg_dump not found. Install PostgreSQL client tools."

# Verify the version was detected    
else
    export PG_VERSION=$(pg_dump --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
    if [ -z "$PG_VERSION" ]; then
        echo "ERROR: Could not detect pg_dump version."
    else
        echo "Detected pg_dump version: $PG_VERSION"
    fi
fi   
```

Now start a PostgreSQL container matching your local version:

```bash
# Pull and run PostgreSQL container matching your local version
docker pull postgres:${PG_VERSION}-alpine

docker run --name test-postgres \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  -d postgres:${PG_VERSION}-alpine

# Wait for PostgreSQL to be ready
sleep 10

# Verify the container is running with the correct version
docker exec test-postgres psql -U testuser -d testdb -c "SELECT version();"
```

> ⚠️ **Note:** If your local `pg_dump` version is very new (e.g., 17+), ensure the corresponding Docker image exists. Check available versions at [Docker Hub PostgreSQL](https://hub.docker.com/_/postgres/tags).

---

### Step 2: Populate with Test Data

```bash
docker exec -i test-postgres psql -U testuser -d testdb <<'EOF'
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER DEFAULT 0
);

INSERT INTO users (username, email) VALUES
    ('john_doe', 'john@example.com'),
    ('jane_smith', 'jane@example.com'),
    ('bob_wilson', 'bob@example.com');

INSERT INTO products (name, price, stock) VALUES
    ('Laptop', 999.99, 10),
    ('Mouse', 25.50, 50),
    ('Keyboard', 79.99, 30);
EOF


docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM users;"
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM products;"
```

### Step 3: Test Backup Script

```bash
export MODE=backup
export STORAGE=local
export SOURCE_DATABASE_URL="postgresql://testuser@localhost:5432/testdb"
export BACKUP_DIR="./test-backups"

mkdir -p test-backups

./pg_dump_tool.sh

ls -lh test-backups/*.dump
```

#### Step 3-1 : Test if backup.dump can be restore successfully

```bash
# Terminate active connections and drop/recreate the database
docker exec -i test-postgres psql -U testuser -d postgres <<'EOF'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'testdb'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS testdb;
CREATE DATABASE testdb;
EOF

```

```bash
# Mount the dump fil into the docker container
docker cp test-backups/pg_backup_YOUR_DUMP_FILE.dump test-postgres:/backup.dump
```

```bash
# Restore the testdb (using pg_restore inside the container to ensure version compatibility)
docker exec -i test-postgres pg_restore -U testuser -d testdb /backup.dump
```

> 💡 **Why restore inside the container?** The restore is performed **inside the container** using the container's `pg_restore` (matching your `$PG_VERSION`). This ensures the `pg_restore` version matches the `pg_dump` version that created the backup, avoiding version mismatch errors.

```bash
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM users;"
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM products;"
```

### Step 4: Test Migration (Optional)

```bash
docker exec test-postgres psql -U testuser -d postgres -c "CREATE DATABASE testdb2;"

export MODE=migrate
export TARGET_DATABASE_URL="postgresql://testuser@localhost:5432/testdb2"
export CONFIRM_MIGRATION=true

./pg_dump_tool.sh

docker exec test-postgres psql -U testuser -d testdb2 -c "SELECT COUNT(*) FROM users;"
docker exec test-postgres psql -U testuser -d testdb2 -c "SELECT COUNT(*) FROM products;"
```

### Step 5: Clean Up

```bash
docker stop test-postgres
docker rm test-postgres

rm -rf test-backups
```

## 🚀 Quick Start Examples

### 1. Simple Local Backup

```bash
export MODE=backup
export STORAGE=local
export SOURCE_DATABASE_URL="postgresql://user@localhost:5432/mydb"
export BACKUP_DIR="./my-backups"
./pg_dump_tool.sh
```

### 2. Backup to S3

```bash
export MODE=backup
export STORAGE=s3
export SOURCE_DATABASE_URL="postgresql://user@localhost:5432/mydb"
export S3_BUCKET="my-backup-bucket"
export AWS_REGION="us-east-1"
export S3_PREFIX="database-backups/"
./pg_dump_tool.sh
```

## ⚙️ Configuration

### Required Environment Variables

| Variable              | Required           | Description                                | Example                           |
| :-------------------- | :----------------- | :----------------------------------------- | :-------------------------------- |
| `MODE`                | Yes                | Operation mode: `backup` or `migrate`      | `backup`                          |
| `STORAGE`             | Yes                | Storage backend: `local` or `s3`           | `s3`                              |
| `SOURCE_DATABASE_URL` | Yes                | Source PostgreSQL connection URL           | `postgresql://user@host:5432/db`  |
| `TARGET_DATABASE_URL` | If `MODE=migrate`  | Target PostgreSQL connection URL           | `postgresql://user@host2:5432/db` |
| `BACKUP_DIR`          | If `STORAGE=local` | Local backup directory                     | `./backups`                       |
| `S3_BUCKET`           | If `STORAGE=s3`    | S3 bucket name                             | `my-backup-bucket`                |
| `AWS_REGION`          | If `STORAGE=s3`    | AWS region                                 | `us-east-1`                       |
| `CONFIRM_MIGRATION`   | If `MODE=migrate`  | Safety flag for migrations (must be `true`)| `true`                            |

### Optional Environment Variables

| Variable                  | Description                                                      | Example             |
| :------------------------ | :--------------------------------------------------------------- | :------------------ |
| `S3_PREFIX`               | S3 key prefix for backup files                                   | `database-backups/` |
| `S3_STORAGE_CLASS`        | S3 storage class for uploaded backups                            | `STANDARD_IA`       |
| `S3_RETENTION_DAYS`       | Set S3 object retention policy (days)                            | `30`                |
| `BACKUP_PREFIX`           | Custom prefix for backup filenames (default: `pg_backup`)        | `myapp_backup`      |
| `LOCAL_RETENTION_DAYS`    | Auto-delete local backups older than N days                      | `7`                 |
| `PG_VERSION`              | Override PostgreSQL version for tool selection                   | `16`                |
| `PG_DUMP_JOBS`            | Number of parallel jobs for pg_dump (requires directory format)  | `4`                 |
| `PG_DUMP_EXTRA_OPTS`      | Additional pg_dump options                                       | `--exclude-table=logs` |
| `PG_RESTORE_JOBS`         | Number of parallel jobs for pg_restore                           | `4`                 |
| `PG_RESTORE_EXTRA_OPTS`   | Additional pg_restore options                                    | `--no-owner`        |
| `IGNORE_VERSION_MISMATCH` | Bypass version mismatch check (not recommended)                  | `true`              |

## 🔐 Security Best Practices

- Use `.pgpass` file for database authentication
- Set appropriate file permissions on the script
- Store environment variables securely
- Use IAM roles instead of access keys for S3 when possible

## 🛠️ Troubleshooting

### PostgreSQL Version Mismatch Errors

The script (v1.1.0+) now **automatically detects** version mismatches and will fail with clear guidance if your local `pg_dump` version is higher than the server version.

**Common error messages:**

```
pg_restore: error: unsupported version (X.Y) in file header
pg_dump: error: server version: X.Y; pg_dump version: Y.Z
```

**The script will show warnings like:**

```
[WARNING] ⚠️  VERSION MISMATCH DETECTED!
[WARNING]    Local pg_dump version (17) is HIGHER than server version (16)
[WARNING]    This may cause compatibility issues during backup/restore operations.
```

**Solutions:**

1. **Use the dynamic Docker setup** (recommended for testing):

   The Quick Test section now automatically matches your Docker container to your local `pg_dump` version:

   ```bash
   export PG_VERSION=$(pg_dump --version | grep -oE '[0-9]+' | head -1)
   docker run -d postgres:${PG_VERSION}-alpine ...
   ```

2. **Install matching PostgreSQL client tools:**

   ```bash
   # Check your current version
   pg_dump --version
   pg_restore --version

   # Install specific version (Ubuntu/Debian):
   sudo apt-get install postgresql-client-<VERSION>

   # Or on macOS with Homebrew:
   brew install postgresql@<VERSION>
   ```

3. **Perform operations inside the container:**

   ```bash
   # Backup inside container
   docker exec test-postgres pg_dump -U testuser -Fc testdb > backup.dump

   # Restore inside container
   docker cp backup.dump test-postgres:/backup.dump
   docker exec test-postgres pg_restore -U testuser -d testdb /backup.dump
   ```

4. **Override version detection** (not recommended):
   ```bash
   export IGNORE_VERSION_MISMATCH=true
   ./pg_dump_tool.sh
   ```

### For connection issues:

```bash
# Test database connection first
psql "$SOURCE_DATABASE_URL" -c "SELECT 1;"

# For .pgpass authentication, ensure the file has proper permissions:
chmod 600 ~/.pgpass
```

### Version Compatibility Rules

| Scenario                                     | Result                    |
| -------------------------------------------- | ------------------------- |
| `pg_dump` version **≤** server version       | ✅ Works                  |
| `pg_dump` version **>** server version       | ⚠️ May work with warnings |
| `pg_restore` version **≥** dump file version | ✅ Works                  |
| `pg_restore` version **<** dump file version | ❌ **Fails**              |

> 💡 **Best Practice:** Always use `pg_restore` with a version **equal to or newer** than the `pg_dump` version that created the backup file.

---

## 🐳 Manual Docker Backup & Restore (Alternative)

> ⚠️ **Note:** The `pg_dump_tool.sh` script **requires local PostgreSQL client tools** (`pg_dump`, `pg_restore`). If you cannot install them, use the manual Docker commands below as an alternative approach. These commands do NOT use the script.

### Backup (Manual Docker)

```bash
# Set your PostgreSQL version
export PG_VERSION=16

# Create backup directory
mkdir -p ./test-backups

# Perform backup inside the container and copy to host
docker exec test-postgres pg_dump -U testuser -Fc testdb > ./test-backups/backup_$(date +%Y%m%d_%H%M%S).dump

# Verify the backup was created
ls -lh ./test-backups/*.dump
```

### Restore (Manual Docker)

```bash
# Find your backup file
BACKUP_FILE=$(ls -t ./test-backups/*.dump | head -1)
echo "Restoring from: $BACKUP_FILE"

# Copy backup into container
docker cp "$BACKUP_FILE" test-postgres:/backup.dump

# Terminate connections and recreate database
docker exec -i test-postgres psql -U testuser -d postgres <<'EOF'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'testdb'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS testdb;
CREATE DATABASE testdb;
EOF

# Restore the database
docker exec test-postgres pg_restore -U testuser -d testdb /backup.dump

# Verify the restore
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM users;"
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM products;"
```

### Restore from Unknown Version Dump File

If you have a dump file but don't know which PostgreSQL version created it:

```bash
# Method 1: Check the dump file header
head -c 100 ./test-backups/backup.dump | strings | grep -oE '[0-9]+\.[0-9]+' | head -1

# Method 2: Try pg_restore --list (shows version info)
# This requires a local pg_restore, but you can use Docker:
docker run --rm -v $(pwd)/test-backups:/backups postgres:16-alpine \
    pg_restore --list /backups/backup.dump 2>&1 | head -10
```

Once you know the version, start a matching container:

```bash
# Example: If dump was created with PostgreSQL 15
export PG_VERSION=15
docker run --name restore-postgres \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=testdb \
  -d postgres:${PG_VERSION}-alpine

# Copy and restore
docker cp ./test-backups/backup.dump restore-postgres:/backup.dump
docker exec restore-postgres pg_restore -U testuser -d testdb /backup.dump
```

---

The Docker test example above provides a complete, self-contained environment to test all script functionality before using it in production.
