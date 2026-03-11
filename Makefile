SHELL := /bin/bash

.PHONY: dbt-deps dbt-debug dbt-seed dbt-run dbt-test docker-build docker-run helm-template localstack-up localstack-down localstack-check minio-check kind-up kind-down secrets-bootstrap secrets-render k8s-secret-sync creds-rotate dev-up dev-down

dbt-deps:
	cd dbt_project && dbt deps --profiles-dir ../config

dbt-debug:
	cd dbt_project && dbt debug --profiles-dir ../config

dbt-seed:
	cd dbt_project && dbt seed --profiles-dir ../config

dbt-run:
	cd dbt_project && dbt run --profiles-dir ../config --select bronze silver gold

dbt-test:
	cd dbt_project && dbt test --profiles-dir ../config

docker-build:
	docker build -t lakehousing-dbt:latest -f infrastructure/docker/Dockerfile .

docker-run:
	docker compose up --build

localstack-up:
	@if [ ! -f .env.local ]; then cp .env.local.example .env.local; fi
	docker compose -f docker-compose.local.yml --env-file .env.local up -d localstack minio minio-init
	bash scripts/secrets-bootstrap.sh
	bash scripts/render-env-from-secrets.sh .env.local.resolved

localstack-down:
	docker compose -f docker-compose.local.yml --env-file .env.local down -v

localstack-check:
	bash scripts/localstack-check.sh

minio-check:
	bash scripts/minio-check.sh

secrets-bootstrap:
	bash scripts/secrets-bootstrap.sh

secrets-render:
	bash scripts/render-env-from-secrets.sh .env.local.resolved

k8s-secret-sync:
	bash scripts/k8s-secret-from-localstack.sh

creds-rotate:
	bash scripts/creds-rotate.sh

kind-up:
	if ! kind get clusters | grep -q '^lakehouse-dev$$'; then kind create cluster --config infrastructure/kind/kind-config.yaml; fi
	kind load docker-image lakehousing-dbt:latest --name lakehouse-dev

kind-down:
	kind delete cluster --name lakehouse-dev

dev-up:
	bash scripts/dev-up.sh

dev-down:
	bash scripts/dev-down.sh

helm-template:
	helm template lakehousing infrastructure/helm/dbt-medallion
