#!/bin/bash
set -e

echo "================================"
echo "Deploying Trino Cluster to Kubernetes"
echo "================================"

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if connected to a Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Not connected to a Kubernetes cluster"
    exit 1
fi

echo "Connected to cluster: $(kubectl config current-context)"
echo ""

# Check for required secrets
echo "Checking for required secrets..."

if ! kubectl get secret aws-credentials &> /dev/null; then
    echo "ERROR: aws-credentials secret not found"
    echo "Create it with:"
    echo "  kubectl create secret generic aws-credentials \\"
    echo "    --from-literal=AWS_ACCESS_KEY_ID=<your-key> \\"
    echo "    --from-literal=AWS_SECRET_ACCESS_KEY=<your-secret>"
    exit 1
fi

if ! kubectl get secret postgres-credentials &> /dev/null; then
    echo "ERROR: postgres-credentials secret not found"
    echo "Create it with:"
    echo "  kubectl create secret generic postgres-credentials \\"
    echo "    --from-literal=POSTGRES_PASSWORD=<strong-password>"
    exit 1
fi

echo "All required secrets found!"
echo ""

# Deploy ConfigMap
echo "Step 1: Deploying Trino ConfigMap..."
kubectl apply -f kubernetes/trino-configmap.yaml
echo "✓ ConfigMap deployed"
echo ""

# Deploy PostgreSQL
echo "Step 2: Deploying PostgreSQL..."
kubectl apply -f kubernetes/postgres.yaml

echo "Waiting for PostgreSQL to be ready (max 120 seconds)..."
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s || {
    echo "WARNING: PostgreSQL pod not ready yet, checking status..."
    kubectl get pods -l app=postgres
    echo "Continuing anyway..."
}
echo "✓ PostgreSQL deployed"
echo ""

# Deploy Hive Metastore
echo "Step 3: Deploying Hive Metastore..."
kubectl apply -f kubernetes/hive-metastore.yaml

echo "Waiting for Hive Metastore to be ready (max 180 seconds)..."
kubectl wait --for=condition=ready pod -l app=hive-metastore --timeout=180s || {
    echo "WARNING: Hive Metastore pod not ready yet, checking status..."
    kubectl get pods -l app=hive-metastore
    echo "Checking logs..."
    kubectl logs -l app=hive-metastore --tail=20 || true
    echo "Continuing anyway..."
}
echo "✓ Hive Metastore deployed"
echo ""

# Deploy Trino Coordinator
echo "Step 4: Deploying Trino Coordinator..."
kubectl apply -f kubernetes/trino-coordinator.yaml

echo "Waiting for Trino Coordinator to be ready (max 180 seconds)..."
kubectl wait --for=condition=ready pod -l app=trino-coordinator --timeout=180s || {
    echo "WARNING: Trino Coordinator pod not ready yet, checking status..."
    kubectl get pods -l app=trino-coordinator
    echo "Continuing anyway..."
}
echo "✓ Trino Coordinator deployed"
echo ""

# Deploy Trino Worker
echo "Step 5: Deploying Trino Worker..."
kubectl apply -f kubernetes/trino-worker.yaml

echo "Waiting for Trino Worker to be ready (max 180 seconds)..."
kubectl wait --for=condition=ready pod -l app=trino-worker --timeout=180s || {
    echo "WARNING: Trino Worker pod not ready yet, checking status..."
    kubectl get pods -l app=trino-worker
    echo "Continuing anyway..."
}
echo "✓ Trino Worker deployed"
echo ""

# Display deployment status
echo "================================"
echo "Deployment Complete!"
echo "================================"
echo ""
echo "Pod Status:"
kubectl get pods
echo ""

echo "Service Status:"
kubectl get services
echo ""

echo "PersistentVolumeClaim Status:"
kubectl get pvc
echo ""

echo "To access Trino UI:"
echo "  kubectl port-forward service/trino-coordinator 8080:8080"
echo "  Then open: http://localhost:8080"
echo ""

echo "To access Trino CLI:"
echo "  kubectl exec -it deployment/trino-coordinator -- trino"
echo ""

echo "To view Hive Metastore logs:"
echo "  kubectl logs deployment/hive-metastore -f"
echo ""

echo "To check PostgreSQL:"
echo "  kubectl exec -it postgres-0 -- psql -U hive -d metastore"
echo ""
