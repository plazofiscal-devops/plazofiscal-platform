#!/usr/bin/env bash
# Deploys the platform on the current cluster context. Secrets are generated here and live only in the cluster.
set -euo pipefail

kubectl apply --filename deploy/app/namespace.yaml

if ! kubectl --namespace plazofiscal get secret app-secrets >/dev/null 2>&1; then
  kubectl --namespace plazofiscal create secret generic app-secrets \
    --from-literal=JWT_SECRET="$(openssl rand -hex 32)"
fi

kubectl apply --kustomize deploy/policies
kubectl apply --kustomize deploy/app
for deployment in auth-api users-api todos-api frontend; do
  kubectl --namespace plazofiscal rollout status "deployment/$deployment" --timeout=10m
done
