#!/usr/bin/env bash
# Deploys the platform on the local cluster. Secrets are generated here and live only in the cluster.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
kube() { kubectl --context "$context" "$@"; }

kube apply --filename deploy/app/namespace.yaml

if ! kube --namespace plazofiscal get secret app-secrets >/dev/null 2>&1; then
  kube --namespace plazofiscal create secret generic app-secrets \
    --from-literal=JWT_SECRET="$(openssl rand -hex 32)"
fi

kube apply --kustomize deploy/policies
kube apply --kustomize deploy/app
for deployment in auth-api users-api todos-api frontend; do
  kube --namespace plazofiscal rollout status "deployment/$deployment" --timeout=10m
done

# The scaling rules own the replica count of the served services.
kube apply --kustomize deploy/autoscaling

kube apply --kustomize deploy/monitoring
