#!/usr/bin/env bash
# Keeps logs and events for 3 days, with no replica on the single Elasticsearch node, and adds the Kibana data views.
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

# Kibana data views for the logs of the services and for Kubernetes events.
kibana() {
  kubectl --context "$context" --namespace observability exec deployment/logs-kb -c kibana -- \
    curl --silent --show-error --fail --user admin:admin --header 'kbn-xsrf: true' \
    --header 'Content-Type: application/json' --request POST "http://localhost:5601/$1" --data "$2" >/dev/null
  echo "$1 done"
}
kibana api/data_views/data_view '{"override": true, "data_view": {"id": "plazofiscal-logs", "name": "PlazoFiscal logs", "title": "logs-plazofiscal-*", "timeFieldName": "@timestamp"}}'
kibana api/data_views/data_view '{"override": true, "data_view": {"id": "kubernetes-events", "name": "Kubernetes events", "title": "logs-kubernetes.events-*", "timeFieldName": "@timestamp"}}'
kibana api/data_views/default '{"data_view_id": "plazofiscal-logs", "force": true}'
