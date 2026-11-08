#!/usr/bin/env bash
# Forwards the operations tools to localhost until Ctrl+C.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
forward() { kubectl --context "$context" --namespace observability port-forward "service/$1" "$2" >/dev/null & }

trap 'kill $(jobs -p) 2>/dev/null' EXIT
forward monitoring-grafana 3000:80
forward kubecost-cost-analyzer 9090:9090
forward monitoring-kube-prometheus-alertmanager 9093:9093
forward monitoring-kube-prometheus-prometheus 9091:9090

cat <<TEXT
Grafana       http://localhost:3000  user admin, password from:
              kubectl --context $context --namespace observability get secret grafana-admin --output jsonpath='{.data.admin-password}' | base64 --decode
Kubecost      http://localhost:9090
Alertmanager  http://localhost:9093
Prometheus    http://localhost:9091
Press Ctrl+C to stop.
TEXT
wait
