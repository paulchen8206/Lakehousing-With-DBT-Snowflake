#!/usr/bin/env bash
set -euo pipefail

for cmd in bash; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

if [[ ! -f .env.local ]]; then
  cp .env.local.example .env.local
  echo "Created .env.local from .env.local.example"
fi

echo "Rotating LocalStack secret payload from .env.local"
bash scripts/secrets-bootstrap.sh

echo "Rendering runtime env from rotated secret"
bash scripts/render-env-from-secrets.sh .env.local.resolved

echo "Syncing Kubernetes secret from rotated LocalStack secret"
bash scripts/k8s-secret-from-localstack.sh

echo "Credential rotation complete"
