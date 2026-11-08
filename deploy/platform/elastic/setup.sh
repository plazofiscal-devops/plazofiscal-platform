#!/usr/bin/env bash
# Keeps logs and events for 3 days, with no replica on the single Elasticsearch node.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
es() {
  kubectl --context "$context" --namespace observability exec logs-es-default-0 -c elasticsearch -- \
    curl --silent --show-error --fail --insecure --user admin:admin \
    --header 'Content-Type: application/json' --request PUT "https://localhost:9200/$1" --data "$2"
  echo
}

es _ilm/policy/plazofiscal-logs '{
  "policy": {
    "phases": {
      "hot": { "actions": { "rollover": { "max_age": "1d", "max_primary_shard_size": "1gb" } } },
      "delete": { "min_age": "3d", "actions": { "delete": {} } }
    }
  }
}'

# logs@custom is the extension point that every logs-*-* data stream reads.
es _component_template/logs@custom '{
  "template": {
    "settings": { "index.lifecycle.name": "plazofiscal-logs", "index.number_of_replicas": 0 }
  }
}'
