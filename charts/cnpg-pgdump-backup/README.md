# CNPG PostgreSQL Backup & Restore Helm Chart

Automated PostgreSQL backup and restore solution for CloudNativePG clusters with S3 storage support.

## Overview

This Helm chart provides:
- **Scheduled backups** using `pg_dump` via Kubernetes CronJob
- **Disaster recovery** via manual Job restore from S3
- **S3 storage** support (AWS S3, MinIO, and S3-compatible storage)
- **Production-ready** security context, resource limits, and health checks

## Local Testing Guide (k3s)

This guide provides instructions for testing the chart locally using a k3s cluster and a standard PostgreSQL deployment (not CNPG).

### Prerequisites

- A running k3s cluster.
- `kubectl` configured to connect to your k3s cluster.
- Helm v3 installed.
- AWS CLI installed and configured.
- An S3 bucket for storing backups.
- Your AWS credentials available. It is recommended to export them as environment variables:
  ```bash
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
  export AWS_S3_BUCKET="your-s3-bucket-name"
  export AWS_REGION="your-s3-bucket-region"
  ```

### 1. Deploy a PostgreSQL Instance

First, deploy a simple PostgreSQL instance and its service into your `default` namespace.

```bash
kubectl run postgres --image=postgres:14 -n default --env="POSTGRES_PASSWORD=supersecret"
kubectl expose deployment postgres --port=5432 -n default
```

Next, create a Kubernetes secret to hold the connection details. The backup job will use this secret to connect to the database. Note that the host is the Kubernetes service DNS name.

```bash
kubectl create secret generic postgres-credentials \
  --from-literal=host='postgres.default.svc.cluster.local' \
  --from-literal=port='5432' \
  --from-literal=username='postgres' \
  --from-literal=password='supersecret' \
  -n default
```

### 2. Install the Chart

Install the Helm chart with the configuration pointing to your local PostgreSQL instance and S3 bucket.

Replace the placeholders with your actual AWS credentials and bucket details. For testing, the schedule is set to run a backup every 5 minutes.

```bash
helm install my-backup . \
  --namespace default \
  --set cnpg.secretName="postgres-credentials" \
  --set cnpg.database="postgres" \
  --set s3.bucket="$AWS_S3_BUCKET" \
  --set s3.region="$AWS_REGION" \
  --set s3.prefix="local-testing" \
  --set s3.awsAccessKeyId="$AWS_ACCESS_KEY_ID" \
  --set s3.awsSecretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set backup.schedule="*/5 * * * *"
```

### 3. Verify the Backup

After installation, a CronJob will be created.

1.  **Check the CronJob:**
    ```bash
    kubectl get cronjob my-backup-cnpg-backup -n default
    ```

2.  **Wait for the first job to run** (or trigger it manually):
    ```bash
    # Trigger a job from the cronjob
    kubectl create job --from=cronjob/my-backup-cnpg-backup manual-backup-1 -n default
    ```

3.  **Check the backup pod logs:**
    Find the pod created by the job and check its logs to see the backup process.
    ```bash
    # Get the pod name
    POD_NAME=$(kubectl get pods -n default --selector=job-name=manual-backup-1 -o jsonpath='{.items[0].metadata.name}')

    # Check the logs
    kubectl logs $POD_NAME -n default
    ```
    You should see output from `pg_dump` and the S3 upload.

4.  **Verify the backup in S3:**
    Check your S3 bucket to confirm the backup file was uploaded.
    ```bash
    aws s3 ls "s3://${AWS_S3_BUCKET}/local-testing/"
    ```

### 4. Test the Restore

1.  **Simulate data loss:**
    Let's connect to the database and drop a table. First, create some dummy data.
    ```bash
    # Connect to the pod
    kubectl exec -it deployment/postgres -n default -- bash

    # Inside the pod, connect to psql and create data
    psql -U postgres
    CREATE TABLE hello (id INT, message TEXT);
    INSERT INTO hello (id, message) VALUES (1, 'world');
    \q
    exit
    ```
    Now run a backup, and after it's complete, delete the table.
    ```bash
    # Trigger a new backup
    kubectl create job --from=cronjob/my-backup-cnpg-backup manual-backup-2 -n default
    # ... wait for it to complete ...

    # Connect again and drop the table
    kubectl exec -it deployment/postgres -n default -- bash
    psql -U postgres
    DROP TABLE hello;
    \q
    exit
    ```

2.  **Trigger the restore:**
    Get the name of the backup file you want to restore from your S3 bucket.
    ```bash
    LATEST_BACKUP=$(aws s3 ls "s3://${AWS_S3_BUCKET}/local-testing/" | sort | tail -n 1 | awk '{print $4}')
    echo "Restoring from: $LATEST_BACKUP"
    ```

    Now, run `helm upgrade` to trigger the restore job.
    ```bash
    helm upgrade my-backup . \
      --namespace default \
      --set cnpg.secretName="postgres-credentials" \
      --set cnpg.database="postgres" \
      --set s3.bucket="$AWS_S3_BUCKET" \
      --set s3.region="$AWS_REGION" \
      --set s3.prefix="local-testing" \
      --set s3.awsAccessKeyId="$AWS_ACCESS_KEY_ID" \
      --set s3.awsSecretAccessKey="$AWS_SECRET_ACCESS_KEY" \
      --set restore.enabled=true \
      --set restore.object="$LATEST_BACKUP" \
      --set restore.force=true \
      --reuse-values
    ```

3.  **Verify the restore:**
    Check the logs of the restore job.
    ```bash
    # Get the restore pod name
    RESTORE_POD_NAME=$(kubectl get pods -l job-name=my-backup-cnpg-pgdump-backup-restore -n default -o jsonpath='{.items[0].metadata.name}')

    # Check logs
    kubectl logs $RESTORE_POD_NAME -n default
    ```
    Connect to the database again and check if the `hello` table is back.
    ```bash
    kubectl exec -it deployment/postgres -n default -- psql -U postgres -c "\dt"
    # You should see the 'hello' table listed.
    ```

### 5. Cleanup

```bash
# Uninstall the Helm release
helm uninstall my-backup -n default

# Delete the PostgreSQL deployment and service
kubectl delete deployment postgres -n default
kubectl delete service postgres -n default

# Delete the secret
kubectl delete secret postgres-credentials -n default

# Delete the manual jobs
kubectl delete job manual-backup-1 manual-backup-2 -n default

# Don't forget to remove the backups from your S3 bucket.
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  CronJob (Backup)                   │   │
│  │  - Runs on schedule (default: daily at 2 AM)        │   │
│  │  - pg_dump → gzip → S3 upload                       │   │
│  │  - Init container: wait for PostgreSQL readiness    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                     Job (Restore)                   │   │
│  │  - Manual trigger via Helm values                   │   │
│  │  - S3 download → gunzip → psql                      │   │
│  │  - Safety check: abort if DB not empty (unless     │   │
│  │    --set restore.force=true)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              CloudNativePG Cluster                  │   │
│  │  - Provides connection secret (host, port, user,   │   │
│  │    password)                                        │   │
│  │  - Database: postgres, appdb, etc.                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
          │
          │ S3 API
          ▼

┌─────────────────────────────────────────────────────────────┐
│                    S3 Storage                                │
│  s3://my-backups-bucket/appdb/                              │
│  ├── appdb_2024-01-21_02-00-00.sql.gz                      │
│  ├── appdb_2024-01-22_02-00-00.sql.gz                      │
│  └── appdb_2024-01-23_02-00-00.sql.gz                      │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- CloudNativePG cluster deployed
- S3 bucket (AWS S3, MinIO, or compatible)
- Existing Kubernetes Secret with CNPG connection details containing:
  - `host`
  - `port`
  - `username`
  - `password`
- Existing Kubernetes Secret with S3 credentials containing:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

## Configuration

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.fullnameOverride` | Full name override | `""` |
| `global.nameOverride` | Name override | `""` |

### Backup Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable scheduled backups | `true` |
| `backup.schedule` | Cron schedule | `"0 2 * * *"` |
| `backup.image` | PostgreSQL image for backup | `"postgres:16"` |
| `backup.imagePullPolicy` | Image pull policy | `"IfNotPresent"` |
| `backup.retentionDays` | Days to retain backups (0 = use S3 lifecycle) | `0` |
| `backup.resources` | Resource limits/requests | See values.yaml |
| `backup.nodeSelector` | Node selector | `{}` |
| `backup.tolerations` | Tolerations | `[]` |
| `backup.affinity` | Affinity rules | `{}` |
| `backup.successfulJobsHistoryLimit` | Number of successful jobs to keep | `3` |
| `backup.failedJobsHistoryLimit` | Number of failed jobs to keep | `3` |
| `backup.concurrencyPolicy` | Concurrency policy (Forbid, Replace, Allow) | `"Forbid"` |

### CNPG Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cnpg.secretName` | Secret name with CNPG connection details | `""` |
| `cnpg.database` | Database name to backup | `""` |
| `cnpg.serviceName` | CNPG cluster service name | `""` |

### S3 Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `s3.bucket` | S3 bucket name | `""` |
| `s3.prefix` | S3 prefix/path within bucket | `""` |
| `s3.region` | AWS region | `"us-east-1"` |
| `s3.endpoint` | S3 endpoint URL (for MinIO/S3-compatible) | `""` |
| `s3.secretName` | Secret name with AWS credentials | `""` |
| `s3.useExistingSecret` | Use existing secret instead of managed | `false` |
| `s3.storageClass` | S3 storage class (optional) | `""` |

### Restore Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `restore.enabled` | Enable restore functionality | `true` |
| `restore.object` | S3 object key to restore (empty = manual) | `""` |
| `restore.force` | Ignore warnings and proceed with restore | `false` |
| `restore.backupBeforeRestore` | Create backup before restore | `false` |
| `restore.resources` | Resource limits/requests | See values.yaml |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `securityContext.runAsNonRoot` | Run as non-root user | `true` |
| `securityContext.runAsUser` | User ID | `999` |
| `securityContext.runAsGroup` | Group ID | `999` |
| `securityContext.readOnlyRootFilesystem` | Read-only root filesystem | `true` |
| `securityContext.allowPrivilegeEscalation` | Disallow privilege escalation | `false` |

## Usage

### Scheduled Backups

Backups run automatically according to the schedule. Each backup:
1. Waits for PostgreSQL to be ready (pg_isready)
2. Performs pg_dump with compression
3. Uploads to S3
4. Cleans up old backups (if configured)

### Disaster Recovery

When disaster strikes (PVCs lost, cluster recreated):

1. **Recreate CNPG cluster** with the same name
2. **Wait for CNPG to create secrets and services**
3. **Trigger restore**:

```bash
# List available backups
aws s3 ls s3://my-backups-bucket/appdb/

# Restore specific backup
helm upgrade cnpg-backup ./charts/cnpg-pgdump-backup \
  --namespace <namespace> \
  --set restore.object=appdb_2024-01-21_02-00-00.sql.gz \
  --set restore.force=true
```

4. **Verify restore**:
```bash
kubectl logs job/<release-name>-cnpg-pgdump-backup-restore
```

### Using MinIO or S3-Compatible Storage

```yaml
s3:
  bucket: my-backups
  prefix: appdb
  region: us-east-1
  endpoint: http://minio.minio.svc.cluster.local:9000
  secretName: s3-backup-creds
```

## Best Practices

### 1. S3 Lifecycle Rules (Recommended)

Configure S3 lifecycle rules instead of script-based retention:

```json
{
  "Rules": [
    {
      "ID": "BackupRetention",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "appdb/"
      },
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
```

### 2. Resource Limits

Adjust resources based on database size:

```yaml
backup:
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

### 3. Monitoring

Add monitoring annotations:

```yaml
monitoring:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
```

### 4. Security

- Use IAM roles for service accounts (IRSA) instead of access keys when possible
- Enable encryption at rest and in transit
- Restrict S3 bucket access with IAM policies
- Use separate S3 credentials for backup with minimal permissions

Example S3 IAM policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-backups-bucket",
        "arn:aws:s3:::my-backups-bucket/appdb/*"
      ]
    }
  ]
}
```

## Troubleshooting

### Backup fails with "PostgreSQL not ready"

The init container waits up to 150 seconds for PostgreSQL. If this fails:
- Check CNPG cluster status: `kubectl get cluster`
- Verify CNPG secret exists: `kubectl get secret <secret-name>`
- Check network policies allowing access to CNPG service

### Restore fails with "Database is not empty"

The restore script has a safety check. To override:
```bash
helm upgrade cnpg-backup ./charts/cnpg-pgdump-backup \
  --set restore.object=<backup-file> \
  --set restore.force=true
```

### S3 upload/download fails

- Verify S3 credentials secret exists and is correct
- Check S3 bucket exists and is accessible
- Verify network access to S3 endpoint
- For MinIO, ensure endpoint URL is correct

### View backup/restore logs

```bash
# Backup logs (from completed job)
kubectl logs job/<release-name>-cnpg-pgdump-backup

# Restore logs
kubectl logs job/<release-name>-cnpg-pgdump-backup-restore
```

## Upgrading

```bash
helm upgrade cnpg-backup ./charts/cnpg-pgdump-backup \
  --namespace <namespace> \
  --set backup.image=postgres:16 \
  --set backup.schedule="0 3 * * *"
```

## Uninstalling

```bash
helm uninstall cnpg-backup -n <namespace>
```

Note: This only removes Helm resources. S3 backups remain in your bucket and must be manually deleted if needed.

## License

Apache License 2.0

## Changelog

### Latest Fixes
- Fixed package manager usage: Replaced `apk` with `apt-get` for Debian-based postgres:16 image
- Fixed PATH value: Removed invalid user ID reference from PATH environment variable
- Fixed missing `file` binary: Replaced with `gzip -t` for gzip validation (guaranteed to exist)
- Fixed S3 secret rendering: Added conditional logic to only render when credentials are provided
- Fixed validation mismatch: Removed `cnpg.database` from required validation for restore operations

