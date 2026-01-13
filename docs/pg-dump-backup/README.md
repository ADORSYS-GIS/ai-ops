# PostgreSQL Backup & Migration Tool

A production-ready shell script for PostgreSQL database backup and migration operations. This tool provides robust, non-interactive backup and migration capabilities with support for multiple storage backends.

## ✨ Features

*   **Dual Modes**: Backup-only or backup-with-migration operations
*   **Multiple Storage Backends**: Local filesystem or AWS S3
*   **Production Safe**: Non-interactive operation with comprehensive error handling
*   **Version Aware**: Auto-detects PostgreSQL version and uses appropriate tools

## 🐳 Quick Test with Docker

### Prerequisites

*   Install Docker: [Docker Installation Guide](https://docs.docker.com/get-docker/)
*   Download the script:

```bash
git clone https://github.com/ADORSYS-GIS/ai-ops.git
cd ai-ops/docs/pg-dump-backup
chmod +x pg_dump_tool.sh
```

* prepare .pgpass env file
```bash
echo "localhost:5432:testdb:testuser:testpass" > $HOME/.pgpass && chmod 600 $HOME/.pgpass
```


### Step 1: Start PostgreSQL Container

> ⚠️ **Important: PostgreSQL Version Compatibility**
>
> This example uses **PostgreSQL 18**. The `pg_restore` command at [line 120](#step-3-1--test-if-backupdump-can-be-restore-successfully) will **fail** if your local PostgreSQL client version is **higher** than the server version (18 in this case).
>
> **Why?** PostgreSQL dump files created with `pg_dump` from a newer version may contain features incompatible with older `pg_restore` versions. Conversely, restoring inside a container with an older PostgreSQL version than your local tools can cause format mismatches.
>
> **Solution:** Ensure your local `pg_dump` version matches or is lower than the container's PostgreSQL version, or perform the restore operation inside the container (as shown in this guide).

Check your local PostgreSQL client version:
```bash
pg_dump --version
```

```bash
docker pull postgres:18-alpine

docker run --name test-postgres \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  -d postgres:18-alpine

sleep 10
```

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
# Restore the testdb (using pg_restore inside the container to avoid version mismatch)
docker exec -i test-postgres pg_restore -U testuser -d testdb /backup.dump
```

> ⚠️ **Note:** The restore is performed **inside the container** using the container's `pg_restore` (PostgreSQL 18). If you attempt to restore from your local machine with a higher PostgreSQL version, you will encounter errors like:
> ```
> pg_restore: error: unsupported version (X.Y) in file header
> ```

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

| Variable            | Required         | Description                           | Example                               |
| :------------------ | :--------------- | :------------------------------------ | :------------------------------------ |
| `MODE`              | Yes              | Operation mode: backup or migrate     | `backup`                              |
| `STORAGE`           | Yes              | Storage backend: local or s3          | `s3`                                  |
| `SOURCE_DATABASE_URL` | Yes              | Source PostgreSQL connection URL      | `postgresql://user@host:5432/db` |
| `TARGET_DATABASE_URL` | If `MODE=migrate` | Target PostgreSQL connection URL      | `postgresql://user@host2:5432/db`|
| `BACKUP_DIR`        | If `STORAGE=local`| Local backup directory                | `./backups`                           |
| `S3_BUCKET`         | If `STORAGE=s3`   | S3 bucket name                        | `my-backup-bucket`                    |
| `AWS_REGION`        | If `STORAGE=s3`   | AWS region                            | `us-east-1`                           |
| `S3_PREFIX`         | No               | S3 key prefix                         | `database-backups/`                   |
| `CONFIRM_MIGRATION` | If `MODE=migrate` | Safety flag for migrations            | `true`                                |

## 🔐 Security Best Practices

*   Use `.pgpass` file for database authentication
*   Set appropriate file permissions on the script
*   Store environment variables securely
*   Use IAM roles instead of access keys for S3 when possible

## 🛠️ Troubleshooting

### PostgreSQL Version Mismatch Errors

> ⚠️ **Critical:** This documentation uses **PostgreSQL 18**. If your local PostgreSQL client tools are a **different version** than the server, you may encounter compatibility issues.

**Common error messages:**
```
pg_restore: error: unsupported version (X.Y) in file header
pg_dump: error: server version: X.Y; pg_dump version: Y.Z
```

**Solutions:**

1. **Match your local PostgreSQL client version to the server:**
   ```bash
   # Check your current version
   pg_dump --version
   pg_restore --version
   
   # Install PostgreSQL 18 client tools (Ubuntu/Debian):
   sudo apt-get install postgresql-client-18
   
   # Or on macOS with Homebrew:
   brew install postgresql@18
   ```

2. **Perform operations inside the container** (recommended for testing):
   ```bash
   # Backup inside container
   docker exec test-postgres pg_dump -U testuser -Fc testdb > backup.dump
   
   # Restore inside container
   docker cp backup.dump test-postgres:/backup.dump
   docker exec test-postgres pg_restore -U testuser -d testdb /backup.dump
   ```

3. **Set the PostgreSQL version explicitly:**
   ```bash
   export PG_VERSION=18
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

| Scenario | Result |
|----------|--------|
| `pg_dump` version **≤** server version | ✅ Works |
| `pg_dump` version **>** server version | ⚠️ May work with warnings |
| `pg_restore` version **≥** dump file version | ✅ Works |
| `pg_restore` version **<** dump file version | ❌ **Fails** |

> 💡 **Best Practice:** Always use `pg_restore` with a version **equal to or newer** than the `pg_dump` version that created the backup file.

The Docker test example above provides a complete, self-contained environment to test all script functionality before using it in production.
