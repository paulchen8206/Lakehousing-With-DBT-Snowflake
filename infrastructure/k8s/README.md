# Raw Kubernetes Deployment

Use these manifests when you want explicit YAML deployment without Helm.

## Prerequisites

- Built and pushed image `lakehousing-dbt:latest` (or update manifest image)
- Secret values configured in `secret.example.yaml`
- A config source for your dbt project (PVC, git-sync, or custom image)

## Apply

```bash
kubectl apply -f infrastructure/k8s/namespace.yaml
kubectl apply -f infrastructure/k8s/secret.example.yaml
kubectl apply -f infrastructure/k8s/configmap.yaml
kubectl apply -f infrastructure/k8s/cronjob.yaml
```
