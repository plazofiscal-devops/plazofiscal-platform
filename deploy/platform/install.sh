#!/usr/bin/env bash
# Installs the platform components from charts pinned to exact versions.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
webhook_file=${ALERT_WEBHOOK_FILE:-$HOME/.config/plazofiscal/alert-webhook}
kubectl=(kubectl --context "$context")

"${kubectl[@]}" create namespace observability --dry-run=client --output yaml | "${kubectl[@]}" apply --filename -

alert_values=()
if [[ -s $webhook_file ]]; then
  "${kubectl[@]}" --namespace observability create secret generic alert-webhook \
    --from-file=url="$webhook_file" --dry-run=client --output yaml | "${kubectl[@]}" apply --filename -
  alert_values=(--values deploy/platform/kube-prometheus-stack/slack.yaml)
else
  echo "No Slack webhook in $webhook_file, so alerts stay inside Alertmanager."
fi

helm upgrade --install monitoring kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts --version 93.1.0 \
  --kube-context "$context" --namespace observability \
  --values deploy/platform/kube-prometheus-stack/values.yaml "${alert_values[@]}" \
  --wait --timeout 15m

# KEDA installs after the monitoring stack, which provides the ServiceMonitor type it uses.
helm upgrade --install keda keda \
  --repo https://kedacore.github.io/charts --version 2.21.0 \
  --kube-context "$context" --namespace keda --create-namespace \
  --values deploy/platform/keda/values.yaml --wait --timeout 10m

helm upgrade --install kubecost cost-analyzer \
  --repo https://kubecost.github.io/cost-analyzer/ --version 2.8.7 \
  --kube-context "$context" --namespace observability \
  --values deploy/platform/kubecost/values.yaml --wait --timeout 15m

helm upgrade --install elastic-operator eck-operator \
  --repo https://helm.elastic.co --version 3.5.0 \
  --kube-context "$context" --namespace elastic-system --create-namespace \
  --values deploy/platform/eck-operator/values.yaml --wait --timeout 10m
