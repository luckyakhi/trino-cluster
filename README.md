# Trino Cluster with Hive Metastore

A production-ready Trino cluster setup using Kubernetes with a custom Hive Metastore image (JDK 11) and PostgreSQL for persistent metadata storage. Query Parquet files from Amazon S3 with full metadata persistence.

## Architecture

The setup includes:
- **Trino Coordinator**: Manages queries and workers (Official trinodb/trino:456 image)
- **Trino Worker**: Executes tasks (Official trinodb/trino:456 image)
- **Hive Metastore**: Custom-built with JDK 11, Hadoop 3.3.6, Hive 3.1.3
- **PostgreSQL**: Persistent metadata storage (replaces ephemeral Derby)

## What's New

✅ **Custom Hive Metastore**: Built from scratch with JDK 11 instead of JDK 8
✅ **PostgreSQL Backend**: Persistent metadata that survives pod restarts
✅ **Individual Dockerfiles**: No more Docker Compose dependency
✅ **Pinned Trino Version**: Using trinodb/trino:456 for stability
✅ **Simplified Deployment**: Clean Kubernetes manifests without inline scripts

## Prerequisites

- Docker Desktop with Kubernetes enabled
- `kubectl` CLI installed and configured
- `make` (optional, for build automation)
- AWS credentials with S3 read access

## Quick Start

### Step 1: Build the Custom Hive Metastore Image

```bash
# Using Make (recommended)
make build-hive

# Or using the build script directly
bash scripts/build-images.sh

# Or manually
docker build -t hive-metastore:3.1.3-jdk11-hadoop3.3.6-local \
  -f dockerfiles/hive-metastore/Dockerfile \
  dockerfiles/hive-metastore/
```

### Step 2: Create Required Kubernetes Secrets

Create AWS credentials secret:
```bash
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=<your-access-key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<your-secret-key>
```

Create PostgreSQL credentials secret:
```bash
kubectl create secret generic postgres-credentials \
  --from-literal=POSTGRES_PASSWORD=<strong-password>
```

> **Important**: Replace `<your-access-key>`, `<your-secret-key>`, and `<strong-password>` with your actual credentials.

### Step 3: Deploy to Kubernetes

```bash
# Using Make (recommended - deploys all services in order)
make deploy-all

# Or using the deployment script
bash scripts/deploy-k8s.sh

# Or manually (in this order)
kubectl apply -f kubernetes/trino-configmap.yaml
kubectl apply -f kubernetes/postgres.yaml
kubectl apply -f kubernetes/hive-metastore.yaml
kubectl apply -f kubernetes/trino-coordinator.yaml
kubectl apply -f kubernetes/trino-worker.yaml
```

### Step 4: Verify Deployment

Check pod status:
```bash
kubectl get pods
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE
postgres-0                          1/1     Running   0          2m
hive-metastore-xxxx                1/1     Running   0          1m
trino-coordinator-xxxx             1/1     Running   0          1m
trino-worker-xxxx                  1/1     Running   0          1m
```

## Accessing the Cluster

### Trino Web UI

Port-forward to access the Trino UI:
```bash
kubectl port-forward service/trino-coordinator 8080:8080
```

Then open [http://localhost:8080](http://localhost:8080) in your browser.

### Trino CLI

Connect to Trino CLI:
```bash
kubectl exec -it deployment/trino-coordinator -- trino
```

## Querying S3 Parquet Files

### Create a Table

The cluster is configured to read from `s3://users.anxietyaicure.com/data/`. Use `s3a://` scheme for Hive compatibility:

```sql
-- Create table pointing to S3 location
CREATE TABLE hive.default.users (
  name VARCHAR,
  age INTEGER,
  diagnosis VARCHAR
) WITH (
  format = 'PARQUET',
  external_location = 's3a://users.anxietyaicure.com/data/'
);

-- Query the data
SELECT * FROM hive.default.users;
```

### Query Any S3 Bucket

You can create tables for any S3 bucket your credentials have access to:

```sql
CREATE TABLE hive.default.<table_name> (
  column1 <type>,
  column2 <type>,
  ...
) WITH (
  format = 'PARQUET',
  external_location = 's3a://<bucket-name>/<path>/'
);
```

### Supported Data Types

| Parquet Type | Trino Type |
|--------------|------------|
| STRING       | VARCHAR    |
| INT32        | INTEGER    |
| INT64        | BIGINT     |
| FLOAT        | REAL       |
| DOUBLE       | DOUBLE     |
| BOOLEAN      | BOOLEAN    |
| DATE         | DATE       |
| TIMESTAMP    | TIMESTAMP  |

### Working with Partitioned Data

For partitioned Parquet data (e.g., `s3://bucket/data/year=2024/month=01/`):

```sql
CREATE TABLE hive.default.partitioned_data (
  name VARCHAR,
  value DOUBLE,
  year VARCHAR,
  month VARCHAR
) WITH (
  format = 'PARQUET',
  external_location = 's3a://bucket/data/',
  partitioned_by = ARRAY['year', 'month']
);

-- Sync partitions with S3
CALL system.sync_partition_metadata('default', 'partitioned_data', 'FULL');

-- Query with partition filter
SELECT * FROM hive.default.partitioned_data WHERE year = '2024';
```

### Useful SQL Commands

```sql
-- List all schemas
SHOW SCHEMAS FROM hive;

-- List all tables in a schema
SHOW TABLES FROM hive.default;

-- Describe table structure
DESCRIBE hive.default.users;

-- Drop a table (metadata only, S3 data is preserved)
DROP TABLE hive.default.users;

-- Show table properties
SHOW CREATE TABLE hive.default.users;
```

## Persistent Metadata

Unlike the previous Derby-based setup, this cluster uses PostgreSQL for metadata storage. This means:

✅ **Table definitions persist** after pod restarts
✅ **Schemas are preserved** during cluster updates
✅ **Partition metadata survives** redeployments

### Verify Metadata Persistence

Test metadata persistence:
```bash
# Create a test table in Trino
kubectl exec -it deployment/trino-coordinator -- trino -e \
  "CREATE TABLE hive.default.persistence_test (id INT)"

# Restart Hive Metastore
kubectl delete pod -l app=hive-metastore

# Wait for new pod to start (about 30 seconds)
kubectl get pods -l app=hive-metastore -w

# Verify table still exists
kubectl exec -it deployment/trino-coordinator -- trino -e \
  "SHOW TABLES FROM hive.default"
```

### Access PostgreSQL Directly

Connect to PostgreSQL to inspect metadata:
```bash
kubectl exec -it postgres-0 -- psql -U hive -d metastore

# List all tables in metastore schema
\dt

# Show Hive tables
SELECT "TBL_NAME" FROM "TBLS";

# Exit
\q
```

## Project Structure

```
trino-cluster/
├── dockerfiles/
│   └── hive-metastore/
│       ├── Dockerfile                     # Custom Hive build with JDK 11
│       ├── entrypoint.sh                  # Initialization script
│       └── config/
│           ├── core-site.xml.template     # S3 configuration
│           └── metastore-site.xml.template # PostgreSQL config
├── kubernetes/
│   ├── postgres.yaml                      # PostgreSQL StatefulSet
│   ├── hive-metastore.yaml                # Hive Metastore deployment
│   ├── trino-configmap.yaml               # Trino configuration
│   ├── trino-coordinator.yaml             # Trino coordinator
│   └── trino-worker.yaml                  # Trino worker
├── scripts/
│   ├── build-images.sh                    # Build helper
│   └── deploy-k8s.sh                      # Deployment helper
├── Makefile                               # Build automation
└── README.md                              # This file
```

## Make Targets

The Makefile provides convenient targets for common operations:

```bash
make help              # Show all available targets
make build-hive        # Build Hive Metastore image
make check-secrets     # Verify required secrets exist
make deploy-postgres   # Deploy PostgreSQL
make deploy-hive       # Deploy Hive Metastore
make deploy-trino      # Deploy Trino coordinator and worker
make deploy-all        # Deploy all services
make clean             # Clean up Kubernetes resources
make clean-images      # Remove local Docker images
```

## Troubleshooting

### Hive Metastore Won't Start

If Hive Metastore fails to start:

1. Check PostgreSQL is running:
   ```bash
   kubectl get pods -l app=postgres
   kubectl logs postgres-0
   ```

2. Check Hive Metastore logs:
   ```bash
   kubectl logs deployment/hive-metastore --tail=50
   ```

3. Verify secrets exist:
   ```bash
   kubectl get secret aws-credentials postgres-credentials
   ```

### Trino Can't Connect to Hive Metastore

If you see `Failed connecting to Hive metastore: [hive-metastore:9083]`:

1. Check if Hive Metastore is running:
   ```bash
   kubectl get pods -l app=hive-metastore
   ```

2. Check Hive Metastore service:
   ```bash
   kubectl get svc hive-metastore
   ```

3. Test connectivity from Trino pod:
   ```bash
   kubectl exec -it deployment/trino-coordinator -- nc -zv hive-metastore 9083
   ```

### S3 Access Denied

If you see S3 access errors:

1. Verify AWS credentials secret:
   ```bash
   kubectl get secret aws-credentials -o yaml
   ```

2. Test credentials from Hive Metastore pod:
   ```bash
   kubectl exec -it deployment/hive-metastore -- env | grep AWS
   ```

3. Confirm IAM permissions include `s3:GetObject` and `s3:ListBucket`

### PostgreSQL Schema Initialization Failed

If schema initialization fails:

1. Check PostgreSQL logs:
   ```bash
   kubectl logs postgres-0
   ```

2. Manually initialize schema:
   ```bash
   kubectl exec -it deployment/hive-metastore -- \
     /opt/hive-metastore/bin/schematool -dbType postgres -initSchema
   ```

### Build Fails

If Docker build fails:

1. Ensure Docker is running:
   ```bash
   docker info
   ```

2. Check internet connectivity (downloads Hadoop, Hive, etc.)

3. Retry with verbose output:
   ```bash
   docker build --no-cache --progress=plain \
     -t hive-metastore:3.1.3-jdk11-hadoop3.3.6-local \
     -f dockerfiles/hive-metastore/Dockerfile \
     dockerfiles/hive-metastore/
   ```

## Restart the Cluster

To restart all components:
```bash
kubectl rollout restart statefulset/postgres
kubectl rollout restart deployment/hive-metastore
kubectl rollout restart deployment/trino-coordinator
kubectl rollout restart deployment/trino-worker
```

## Clean Up

To completely remove the cluster:
```bash
# Using Make
make clean

# Manually
kubectl delete -f kubernetes/
kubectl delete secret aws-credentials postgres-credentials
kubectl delete pvc postgres-storage-postgres-0
```

## Scaling Workers

To scale Trino workers:
```bash
# Scale to 3 workers
kubectl scale deployment/trino-worker --replicas=3

# Verify
kubectl get pods -l app=trino-worker
```

## Upgrading

### Upgrade Trino Version

To upgrade Trino to a newer version:

1. Update image tag in [kubernetes/trino-coordinator.yaml](kubernetes/trino-coordinator.yaml) and [kubernetes/trino-worker.yaml](kubernetes/trino-worker.yaml):
   ```yaml
   image: trinodb/trino:457  # Change version number
   ```

2. Redeploy:
   ```bash
   kubectl apply -f kubernetes/trino-coordinator.yaml
   kubectl apply -f kubernetes/trino-worker.yaml
   ```

### Rebuild Hive Metastore Image

To rebuild with updated dependencies:

1. Modify versions in [dockerfiles/hive-metastore/Dockerfile](dockerfiles/hive-metastore/Dockerfile)
2. Rebuild:
   ```bash
   make build-hive
   ```
3. Redeploy:
   ```bash
   kubectl rollout restart deployment/hive-metastore
   ```

## Technical Details

### Custom Hive Metastore Image

- **Base Image**: eclipse-temurin:11-jre-jammy (OpenJDK 11)
- **Hadoop Version**: 3.3.6
- **Hive Version**: 3.1.3 (standalone metastore)
- **AWS SDK**: 1.12.262
- **PostgreSQL Driver**: 42.7.1
- **Features**:
  - S3A filesystem support
  - Template-based configuration with envsubst
  - Automatic schema initialization
  - PostgreSQL connection pooling (HikariCP)

### Environment Variables

**Hive Metastore**:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` - AWS credentials
- `AWS_REGION` - AWS region (default: ap-south-1)
- `S3_BUCKET` - S3 bucket name
- `DB_HOST`, `DB_PORT`, `DB_NAME` - PostgreSQL connection
- `DB_USER`, `DB_PASSWORD` - PostgreSQL credentials

**PostgreSQL**:
- `POSTGRES_DB` - Database name (metastore)
- `POSTGRES_USER` - Database user (hive)
- `POSTGRES_PASSWORD` - Database password (from secret)

## Changelog

**v2.0** - Current version
- Custom Hive Metastore with JDK 11
- PostgreSQL persistent storage
- Removed Docker Compose
- Pinned Trino version 456
- Simplified Kubernetes manifests

**v1.0** - Legacy version
- Docker Compose setup
- Pre-built images
- Derby ephemeral storage
- Trino :latest tag
