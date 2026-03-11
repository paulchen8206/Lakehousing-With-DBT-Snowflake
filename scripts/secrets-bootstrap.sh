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

payload=$(jq -n \
  --arg snowflake_account "${SNOWFLAKE_ACCOUNT:-}" \
  --arg snowflake_user "${SNOWFLAKE_USER:-}" \
  --arg snowflake_password "${SNOWFLAKE_PASSWORD:-}" \
  --arg snowflake_role "${SNOWFLAKE_ROLE:-TRANSFORMER}" \
  --arg snowflake_warehouse "${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}" \
  --arg snowflake_database "${SNOWFLAKE_DATABASE:-LAKEHOUSE}" \
  --arg snowflake_schema "${SNOWFLAKE_SCHEMA:-RAW}" \
  --arg dbt_target "${DBT_TARGET:-dev}" \
  --arg aws_region "${AWS_REGION:-us-east-1}" \
  --arg s3_bucket "${S3_BUCKET:-lakehouse-raw-local}" \
  --arg minio_endpoint "${MINIO_ENDPOINT_INTERNAL:-http://minio:9000}" \
  --arg minio_access_key "${MINIO_ROOT_USER:-minioadmin}" \
  --arg minio_secret_key "${MINIO_ROOT_PASSWORD:-minioadmin}" \
  '{
    SNOWFLAKE_ACCOUNT: $snowflake_account,
    SNOWFLAKE_USER: $snowflake_user,
    SNOWFLAKE_PASSWORD: $snowflake_password,
    SNOWFLAKE_ROLE: $snowflake_role,
    SNOWFLAKE_WAREHOUSE: $snowflake_warehouse,
    SNOWFLAKE_DATABASE: $snowflake_database,
    SNOWFLAKE_SCHEMA: $snowflake_schema,
    DBT_TARGET: $dbt_target,
    AWS_REGION: $aws_region,
    S3_BUCKET: $s3_bucket,
    MINIO_ENDPOINT: $minio_endpoint,
    MINIO_ACCESS_KEY: $minio_access_key,
    MINIO_SECRET_KEY: $minio_secret_key
  }')

if aws --endpoint-url "$endpoint" secretsmanager describe-secret --secret-id "$secret_id" >/dev/null 2>&1; then
  aws --endpoint-url "$endpoint" secretsmanager put-secret-value \
    --secret-id "$secret_id" \
    --secret-string "$payload" >/dev/null
  echo "Updated secret in LocalStack: $secret_id"
else
  aws --endpoint-url "$endpoint" secretsmanager create-secret \
    --name "$secret_id" \
    --secret-string "$payload" >/dev/null
  echo "Created secret in LocalStack: $secret_id"
fi
