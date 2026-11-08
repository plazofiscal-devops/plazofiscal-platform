# Platform components

Each component installs from a chart or operator pinned to an exact version, with reduced memory settings in this folder. `make platform` runs `install.sh`, which installs the components that exist so far, and `make up` calls it. [Architecture](../../docs/architecture.md) gives the memory budget of each one.

| Component | Namespace | Purpose |
|---|---|---|
| Traefik | `ingress` | Entry point |
| KEDA 2.21.0 | `keda` | Scaling by date and load |
| kube-prometheus-stack | `observability` | Metrics, alerts and Grafana |
| Kubecost | `observability` | Cost by namespace and service |
| ECK with Elasticsearch, Logstash and Kibana | `observability` | Logs |
| Jaeger | `observability` | Traces |
| Kubernetes event exporter | `observability` | Events |
| Keycloak and oauth2-proxy | `identity` | Sign-in with a second factor |
