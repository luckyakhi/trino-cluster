.PHONY: help build-hive deploy-postgres deploy-hive deploy-trino deploy-all clean check-secrets

# Configuration
HIVE_IMAGE := hive-metastore
HIVE_VERSION := 3.1.3-jdk11-hadoop3.3.6
TAG := local
FULL_IMAGE_NAME := $(HIVE_IMAGE):$(HIVE_VERSION)-$(TAG)

help:
	@echo "Available targets:"
	@echo "  build-hive         - Build Hive Metastore Docker image"
	@echo "  check-secrets      - Verify required Kubernetes secrets exist"
	@echo "  deploy-postgres    - Deploy PostgreSQL StatefulSet to Kubernetes"
	@echo "  deploy-hive        - Deploy Hive Metastore to Kubernetes"
	@echo "  deploy-trino       - Deploy Trino coordinator and worker to Kubernetes"
	@echo "  deploy-all         - Deploy all services (postgres, hive, trino)"
	@echo "  clean              - Clean up Kubernetes resources and local images"
	@echo "  clean-images       - Remove local Docker images only"

build-hive:
	@echo "Building Hive Metastore image..."
	docker build -t $(FULL_IMAGE_NAME) \
		-f dockerfiles/hive-metastore/Dockerfile \
		dockerfiles/hive-metastore/
	@echo "Successfully built: $(FULL_IMAGE_NAME)"
	@docker images | grep hive-metastore

check-secrets:
	@echo "Checking for required Kubernetes secrets..."
	@kubectl get secret aws-credentials >/dev/null 2>&1 || \
		(echo "ERROR: aws-credentials secret not found. Create it with:" && \
		 echo "  kubectl create secret generic aws-credentials \\" && \
		 echo "    --from-literal=AWS_ACCESS_KEY_ID=<your-key> \\" && \
		 echo "    --from-literal=AWS_SECRET_ACCESS_KEY=<your-secret>" && \
		 exit 1)
	@kubectl get secret postgres-credentials >/dev/null 2>&1 || \
		(echo "ERROR: postgres-credentials secret not found. Create it with:" && \
		 echo "  kubectl create secret generic postgres-credentials \\" && \
		 echo "    --from-literal=POSTGRES_PASSWORD=<strong-password>" && \
		 exit 1)
	@echo "All required secrets found!"

deploy-postgres: check-secrets
	@echo "Deploying PostgreSQL StatefulSet..."
	kubectl apply -f kubernetes/postgres.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s || true
	@echo "PostgreSQL deployed!"

deploy-hive: check-secrets
	@echo "Deploying Hive Metastore..."
	kubectl apply -f kubernetes/hive-metastore.yaml
	@echo "Waiting for Hive Metastore to be ready..."
	kubectl wait --for=condition=ready pod -l app=hive-metastore --timeout=180s || true
	@echo "Hive Metastore deployed!"

deploy-trino: check-secrets
	@echo "Deploying Trino ConfigMap..."
	kubectl apply -f kubernetes/trino-configmap.yaml
	@echo "Deploying Trino Coordinator..."
	kubectl apply -f kubernetes/trino-coordinator.yaml
	@echo "Deploying Trino Worker..."
	kubectl apply -f kubernetes/trino-worker.yaml
	@echo "Waiting for Trino pods to be ready..."
	kubectl wait --for=condition=ready pod -l app=trino-coordinator --timeout=180s || true
	kubectl wait --for=condition=ready pod -l app=trino-worker --timeout=180s || true
	@echo "Trino deployed!"

deploy-all: deploy-postgres deploy-hive deploy-trino
	@echo ""
	@echo "All services deployed successfully!"
	@echo ""
	@echo "Check status with:"
	@echo "  kubectl get pods"
	@echo ""
	@echo "Access Trino UI:"
	@echo "  kubectl port-forward service/trino-coordinator 8080:8080"
	@echo "  Open http://localhost:8080"

clean:
	@echo "Cleaning up Kubernetes resources..."
	-kubectl delete -f kubernetes/trino-worker.yaml
	-kubectl delete -f kubernetes/trino-coordinator.yaml
	-kubectl delete -f kubernetes/hive-metastore.yaml
	-kubectl delete -f kubernetes/postgres.yaml
	-kubectl delete -f kubernetes/trino-configmap.yaml
	@echo "Kubernetes resources cleaned up!"

clean-images:
	@echo "Removing local Docker images..."
	-docker rmi $(FULL_IMAGE_NAME)
	@echo "Local images cleaned up!"
