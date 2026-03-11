#!/usr/bin/env bash
set -euo pipefail

helm uninstall lakehousing --namespace lakehouse-dbt >/dev/null 2>&1 || true
kind delete cluster --name lakehouse-dev >/dev/null 2>&1 || true
docker compose -f docker-compose.local.yml --env-file .env.local down -v >/dev/null 2>&1 || true
rm -f .env.local.resolved

echo "Local dev stack is down"
