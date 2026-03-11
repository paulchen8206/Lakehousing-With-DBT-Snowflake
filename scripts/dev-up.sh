#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd docker
require_cmd kind
require_cmd kubectl
require_cmd helm
require_cmd curl
require_cmd aws
require_cmd jq

if [[ ! -f .env.local ]]; then
  cp .env.local.example .env.local
  echo "Created .env.local from .env.local.example"
fi

chmod +x scripts/secrets-bootstrap.sh scripts/render-env-from-secrets.sh scripts/k8s-secret-from-localstack.sh scripts/minio-check.sh scripts/snowflake-verify.sh

echo "Starting LocalStack + MinIO"
docker compose -f docker-compose.local.yml --env-file .env.local up -d --build localstack minio minio-init

echo "Waiting for LocalStack health"
for _ in {1..30}; do
  if curl -fsS http://localhost:4566/_localstack/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Bootstrapping LocalStack secret values"
bash scripts/secrets-bootstrap.sh

echo "Rendering dbt runtime environment from LocalStack Secrets Manager"
bash scripts/render-env-from-secrets.sh .env.local.resolved

echo "Verifying Snowflake prerequisites before Kubernetes deployment"
bash scripts/snowflake-verify.sh .env.local.resolved

echo "Validating MinIO seed data"
bash scripts/minio-check.sh

echo "Building dbt image"
docker build -t lakehousing-dbt:latest -f infrastructure/docker/Dockerfile .

echo "Creating Kind cluster if missing"
if ! kind get clusters | grep -q '^lakehouse-dev$'; then
  kind create cluster --config infrastructure/kind/kind-config.yaml
fi

echo "Loading dbt image into Kind"
kind load docker-image lakehousing-dbt:latest --name lakehouse-dev

echo "Syncing Kubernetes secret from LocalStack Secrets Manager"
bash scripts/k8s-secret-from-localstack.sh

echo "Deploying Helm release"
helm upgrade --install lakehousing infrastructure/helm/dbt-medallion \
  --namespace lakehouse-dbt \
  --create-namespace \
  -f infrastructure/helm/dbt-medallion/values.local.yaml

echo "Local dev stack is up"
