# Platform components

Each component installs from a chart or operator pinned to an exact version, with reduced memory settings in this folder. `make platform` runs `install.sh`, which installs the components that exist so far, and `make up` calls it. The monitoring stack installs first, since KEDA and Kubecost declare ServiceMonitors that need its resource types. The installation turns the Slack webhook file described in [operations](../../docs/operations.md) into another Secret when the file exists. [Architecture](../../docs/architecture.md) gives the memory budget of each one.

| Component | Namespace | Purpose |
|---|---|---|
| Traefik | `ingress` | Entry point |
| KEDA 2.21.0 | `keda` | Scaling by date and load |
| kube-prometheus-stack 93.1.0 | `observability` | Prometheus, Alertmanager, Grafana and exporters |
| Kubecost 2.8.7 | `observability` | Cost by namespace and service, from the same Prometheus |
| ECK with Elasticsearch, Logstash and Kibana | `observability` | Logs |
| Jaeger | `observability` | Traces |
| Kubernetes event exporter | `observability` | Events |
| Keycloak and oauth2-proxy | `identity` | Sign-in with a second factor |
