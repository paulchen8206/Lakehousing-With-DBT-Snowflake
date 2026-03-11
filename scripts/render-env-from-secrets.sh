#!/usr/bin/env bash
set -euo pipefail

for cmd in aws jq; do
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
out_file="${1:-.env.local.resolved}"

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

{
  echo "SNOWFLAKE_ACCOUNT=$(jq -r '.SNOWFLAKE_ACCOUNT // empty' <<<"$secret_json")"
  echo "SNOWFLAKE_USER=$(jq -r '.SNOWFLAKE_USER // empty' <<<"$secret_json")"
  echo "SNOWFLAKE_PASSWORD=$(jq -r '.SNOWFLAKE_PASSWORD // empty' <<<"$secret_json")"
  echo "SNOWFLAKE_ROLE=$(jq -r '.SNOWFLAKE_ROLE // empty' <<<"$secret_json")"
  echo "SNOWFLAKE_WAREHOUSE=$(jq -r '.SNOWFLAKE_WAREHOUSE // empty' <<<"$secret_json")"
  echo "SNOWFLAKE_DATABASE=$(jq -r '.SNOWFLAKE_DATABASE // empty' <<<"$secret_json")"
  echo "SNOWFLAKE_SCHEMA=$(jq -r '.SNOWFLAKE_SCHEMA // empty' <<<"$secret_json")"
  echo "DBT_TARGET=$(jq -r '.DBT_TARGET // empty' <<<"$secret_json")"
} > "$out_file"

echo "Wrote resolved runtime env to $out_file"
