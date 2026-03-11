#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env ]]; then
  echo "Creating .env from .env.example"
  cp .env.example .env
fi

echo "Build dbt image"
docker build -t lakehousing-dbt:latest -f infrastructure/docker/Dockerfile .

echo "Done. Update .env and run: docker compose up --build"
