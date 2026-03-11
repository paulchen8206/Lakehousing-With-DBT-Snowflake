#!/usr/bin/env bash
set -euo pipefail

for cmd in aws curl jq; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Missing required command: $cmd"
		exit 1
	fi
done

endpoint="${LOCALSTACK_ENDPOINT_HOST:-http://localhost:4566}"
secret_id="${SECRET_ID:-lakehouse/dev/credentials}"

echo "LocalStack health:"
curl -fsS "${endpoint}/_localstack/health" | jq .

echo "Secrets in LocalStack:"
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test} \
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test} \
aws --endpoint-url "${endpoint}" secretsmanager list-secrets | jq .

echo "Credential payload in ${secret_id}:"
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test} \
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test} \
aws --endpoint-url "${endpoint}" secretsmanager get-secret-value \
	--secret-id "${secret_id}" \
	--query SecretString \
	--output text | jq .
