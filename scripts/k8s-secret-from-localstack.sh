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

secret_response=$(aws --endpoint-url "$endpoint" secretsmanager get-secret-value \
  --secret-id "$secret_id" \
  --output json)

secret_json=$(jq -cer '
  def to_object:
    if type == "object" then .
    elif type == "string" then (fromjson? // {})
    else {}
    end;
  (.SecretString // {}) | to_object
' <<<"$secret_response")

if [[ "$secret_json" == "{}" ]]; then
  echo "Secret $secret_id in $endpoint did not contain a valid JSON SecretString"
  exit 1
fi

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl create secret generic "$secret_name" \
  --namespace "$namespace" \
  --from-literal=SNOWFLAKE_ACCOUNT="$(jq -r '.SNOWFLAKE_ACCOUNT // empty' <<<"$secret_json")" \
  --from-literal=SNOWFLAKE_USER="$(jq -r '.SNOWFLAKE_USER // empty' <<<"$secret_json")" \
  --from-literal=SNOWFLAKE_PASSWORD="$(jq -r '.SNOWFLAKE_PASSWORD // empty' <<<"$secret_json")" \
  --from-literal=SNOWFLAKE_ROLE="$(jq -r '.SNOWFLAKE_ROLE // empty' <<<"$secret_json")" \
  --from-literal=SNOWFLAKE_WAREHOUSE="$(jq -r '.SNOWFLAKE_WAREHOUSE // empty' <<<"$secret_json")" \
  --from-literal=SNOWFLAKE_DATABASE="$(jq -r '.SNOWFLAKE_DATABASE // empty' <<<"$secret_json")" \
  --from-literal=SNOWFLAKE_SCHEMA="$(jq -r '.SNOWFLAKE_SCHEMA // empty' <<<"$secret_json")" \
  --from-literal=DBT_TARGET="$(jq -r '.DBT_TARGET // empty' <<<"$secret_json")" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "Applied Kubernetes secret $secret_name in namespace $namespace from LocalStack secret $secret_id"
