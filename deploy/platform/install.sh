#!/usr/bin/env bash
# Installs the platform components from charts pinned to exact versions.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}

helm upgrade --install keda keda \
  --repo https://kedacore.github.io/charts --version 2.21.0 \
  --kube-context "$context" --namespace keda --create-namespace \
  --values deploy/platform/keda/values.yaml --wait --timeout 10m
