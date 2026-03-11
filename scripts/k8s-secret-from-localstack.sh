#!/usr/bin/env bash
set -euo pipefail

for cmd in aws jq kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

endpoint="${LOCALSTACK_ENDPOINT_HOST:-http://localhost:4566}"
secret_id="${SECRET_ID:-lakehouse/dev/credentials}"
namespace="${K8S_NAMESPACE:-lakehouse-dbt}"
secret_name="${K8S_DBT_SECRET_NAME:-dbt-snowflake-secret}"

secret_json=$(aws --endpoint-url "$endpoint" secretsmanager get-secret-value \
  --secret-id "$secret_id" \
  --query SecretString \
  --output text)

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl create secret generic "$secret_name" \
  --namespace "$namespace" \
  --from-literal=SNOWFLAKE_ACCOUNT="$(jq -r '.SNOWFLAKE_ACCOUNT' <<<\"$secret_json\")" \
  --from-literal=SNOWFLAKE_USER="$(jq -r '.SNOWFLAKE_USER' <<<\"$secret_json\")" \
  --from-literal=SNOWFLAKE_PASSWORD="$(jq -r '.SNOWFLAKE_PASSWORD' <<<\"$secret_json\")" \
  --from-literal=SNOWFLAKE_ROLE="$(jq -r '.SNOWFLAKE_ROLE' <<<\"$secret_json\")" \
  --from-literal=SNOWFLAKE_WAREHOUSE="$(jq -r '.SNOWFLAKE_WAREHOUSE' <<<\"$secret_json\")" \
  --from-literal=SNOWFLAKE_DATABASE="$(jq -r '.SNOWFLAKE_DATABASE' <<<\"$secret_json\")" \
  --from-literal=SNOWFLAKE_SCHEMA="$(jq -r '.SNOWFLAKE_SCHEMA' <<<\"$secret_json\")" \
  --from-literal=DBT_TARGET="$(jq -r '.DBT_TARGET' <<<\"$secret_json\")" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "Applied Kubernetes secret $secret_name in namespace $namespace from LocalStack secret $secret_id"
