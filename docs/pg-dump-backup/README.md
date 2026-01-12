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

### Step 1: Start PostgreSQL Container

```bash
docker pull postgres:15-alpine

docker run --name test-postgres \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  -d postgres:15-alpine

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
export SOURCE_DATABASE_URL="postgresql://testuser:testpass@localhost:5432/testdb"
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
# Restore the testdb
docker exec -i test-postgres pg_restore -U testuser -d testdb /backup.dump
```

```bash
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM users;"
docker exec test-postgres psql -U testuser -d testdb -c "SELECT COUNT(*) FROM products;"
```

### Step 4: Test Migration (Optional)

```bash
docker exec test-postgres psql -U testuser -d postgres -c "CREATE DATABASE testdb2;"   

export MODE=migrate
export TARGET_DATABASE_URL="postgresql://testuser:testpass@localhost:5432/testdb2"
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
export SOURCE_DATABASE_URL="postgresql://user:password@localhost:5432/mydb"
export BACKUP_DIR="./my-backups"
./pg_dump_tool.sh
```

### 2. Backup to S3

```bash
export MODE=backup
export STORAGE=s3
export SOURCE_DATABASE_URL="postgresql://user:password@localhost:5432/mydb"
export S3_BUCKET="my-backup-bucket"
export AWS_REGION="us-east-1"
export S3_PREFIX="database-backups/"
./pg_dump_tool.sh
```

## 📋 Prerequisites

*   PostgreSQL Client Tools: `pg_dump`, `pg_restore`, `psql`
*   AWS CLI (for S3 storage option)
*   Bash 4.0+

## ⚙️ Configuration

| Variable            | Required         | Description                           | Example                               |
| :------------------ | :--------------- | :------------------------------------ | :------------------------------------ |
| `MODE`              | Yes              | Operation mode: backup or migrate     | `backup`                              |
| `STORAGE`           | Yes              | Storage backend: local or s3          | `s3`                                  |
| `SOURCE_DATABASE_URL` | Yes              | Source PostgreSQL connection URL      | `postgresql://user:pass@host:5432/db` |
| `TARGET_DATABASE_URL` | If `MODE=migrate` | Target PostgreSQL connection URL      | `postgresql://user:pass@host2:5432/db`|
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

If you encounter version mismatch errors:

```bash
# Install specific PostgreSQL version tools
# Ubuntu/Debian:
sudo apt-get install postgresql-client-15

# Or set the version explicitly:
export PG_VERSION=15
./pg_dump_tool.sh
```

For connection issues:

```bash
# Test database connection first
psql "$SOURCE_DATABASE_URL" -c "SELECT 1;"
```

The Docker test example above provides a complete, self-contained environment to test all script functionality before using it in production.
