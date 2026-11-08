#!/usr/bin/env bash
# Installs the platform components from charts pinned to exact versions.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
webhook_file=${ALERT_WEBHOOK_FILE:-$HOME/.config/plazofiscal/alert-webhook}
kubectl=(kubectl --context "$context")


"${kubectl[@]}" create namespace observability --dry-run=client --output yaml | "${kubectl[@]}" apply --filename -

# Sign-in. The client secrets and the Keycloak admin password are generated once and live only in the cluster.
"${kubectl[@]}" create namespace identity --dry-run=client --output yaml | "${kubectl[@]}" apply --filename -
if ! "${kubectl[@]}" --namespace identity get secret sso >/dev/null 2>&1; then
  proxy_secret=$(openssl rand -hex 24)
  grafana_secret=$(openssl rand -hex 24)
  "${kubectl[@]}" --namespace identity create secret generic sso \
    --from-literal=keycloak-admin-password="$(openssl rand -hex 16)" \
    --from-literal=oauth2-proxy-client-secret="$proxy_secret" \
    --from-literal=grafana-client-secret="$grafana_secret"
  "${kubectl[@]}" --namespace identity create secret generic oauth2-proxy \
    --from-literal=client-id=oauth2-proxy --from-literal=client-secret="$proxy_secret" \
    --from-literal=cookie-secret="$(openssl rand -hex 16)"
  "${kubectl[@]}" --namespace observability create secret generic grafana-oidc \
    --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET="$grafana_secret" \
    --dry-run=client --output yaml | "${kubectl[@]}" apply --filename -
fi

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

# Traefik installs after the monitoring stack, which provides the ServiceMonitor type it uses.
helm upgrade --install traefik traefik \
  --repo https://traefik.github.io/charts --version 42.3.1 \
  --kube-context "$context" --namespace ingress --create-namespace \
  --values deploy/platform/traefik/values.yaml --wait --timeout 10m
if "${kubectl[@]}" apply --filename deploy/platform/traefik/dns.yaml | grep -q -E 'created|configured'; then
  "${kubectl[@]}" --namespace kube-system rollout restart deployment/coredns
fi

# KEDA installs after the monitoring stack, which provides the ServiceMonitor type it uses.
helm upgrade --install keda keda \
  --repo https://kedacore.github.io/charts --version 2.21.0 \
  --kube-context "$context" --namespace keda --create-namespace \
  --values deploy/platform/keda/values.yaml --wait --timeout 10m

# Kubecost runs only for cost reviews, since the machine has no room for every tool at once.
# Its chart cannot set zero replicas, so it is scaled after each install. COSTS=on keeps it running.
helm upgrade --install kubecost cost-analyzer \
  --repo https://kubecost.github.io/cost-analyzer/ --version 2.8.7 \
  --kube-context "$context" --namespace observability \
  --values deploy/platform/kubecost/values.yaml
if [[ ${COSTS:-off} != on ]]; then
  "${kubectl[@]}" --namespace observability scale deployment/kubecost-cost-analyzer --replicas=0
fi

helm upgrade --install elastic-operator eck-operator \
  --repo https://helm.elastic.co --version 3.5.0 \
  --kube-context "$context" --namespace elastic-system --create-namespace \
  --values deploy/platform/eck-operator/values.yaml --wait --timeout 10m

elastic_existed=false
"${kubectl[@]}" --namespace observability get secret logs-es-elastic-user >/dev/null 2>&1 && elastic_existed=true
"${kubectl[@]}" apply --kustomize deploy/platform/elastic
"${kubectl[@]}" --namespace observability wait elasticsearch/logs --for=jsonpath='{.status.health}'=green --timeout=10m
"${kubectl[@]}" --namespace observability wait kibana/logs --for=jsonpath='{.status.health}'=green --timeout=10m
KUBE_CONTEXT=$context bash deploy/platform/elastic/setup.sh
# Grafana reads the elastic password at start, so a first install restarts it once the password exists.
if [[ $elastic_existed == false ]]; then
  "${kubectl[@]}" --namespace observability rollout restart deployment/monitoring-grafana
fi

for release in logs events; do
  helm upgrade --install "fluent-bit-$release" fluent-bit \
    --repo https://fluent.github.io/helm-charts --version 0.58.3 \
    --kube-context "$context" --namespace observability \
    --values "deploy/platform/fluent-bit/$release.yaml" --wait --timeout 10m
done

# Jaeger 2.19 is the last line with the query API that the Grafana Jaeger data source calls.
helm upgrade --install jaeger-collector jaeger \
  --repo https://jaegertracing.github.io/helm-charts --version 4.11.2 \
  --kube-context "$context" --namespace observability \
  --values deploy/platform/jaeger/values.yaml --wait --timeout 10m

"${kubectl[@]}" apply --kustomize deploy/platform/keycloak
"${kubectl[@]}" --namespace identity rollout status deployment/keycloak --timeout=10m

helm upgrade --install oauth2-proxy oauth2-proxy \
  --repo https://oauth2-proxy.github.io/manifests --version 10.7.2 \
  --kube-context "$context" --namespace identity \
  --values deploy/platform/oauth2-proxy/values.yaml --wait --timeout 10m
"${kubectl[@]}" apply --filename deploy/platform/oauth2-proxy/middlewares.yaml
"${kubectl[@]}" apply --kustomize deploy/platform/oauth2-proxy/forbidden

