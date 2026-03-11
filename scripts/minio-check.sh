#!/usr/bin/env bash
set -euo pipefail

for cmd in aws; do
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

endpoint="${MINIO_ENDPOINT_HOST:-http://localhost:9000}"
bucket="${S3_BUCKET:-lakehouse-raw-local}"

echo "Buckets in MinIO (${endpoint}):"
AWS_ACCESS_KEY_ID="${MINIO_ROOT_USER:-minioadmin}" \
AWS_SECRET_ACCESS_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}" \
AWS_PAGER="" \
aws --endpoint-url "$endpoint" s3 ls \
  --region "${AWS_REGION:-us-east-1}"

echo "Objects under s3://${bucket}/orders/"
AWS_ACCESS_KEY_ID="${MINIO_ROOT_USER:-minioadmin}" \
AWS_SECRET_ACCESS_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}" \
AWS_PAGER="" \
aws --endpoint-url "$endpoint" s3 ls "s3://${bucket}/orders/" \
  --region "${AWS_REGION:-us-east-1}"
