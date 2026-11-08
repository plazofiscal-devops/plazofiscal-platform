# Evidence

This document maps each point of the course to the way the platform proves it, the command that repeats the proof, and the screenshots taken on the reference machine. The figures come from the runs described in the [architecture](architecture.md), and the screenshots live in `evidence/`.

## Contents

1. Summary
2. Points of the course
3. Screenshots

## 1. Summary

| Point | Proof | Repeat it with |
|---|---|---|
| Application on Kubernetes with network policies and persistent storage | 31 network paths behave as declared, and obligations survive a Redis restart | `make check-policies` |
| Rolling deployment | Four releases under load served 9272 requests with no failure | `make load` with `make rollout` |
| Autoscaling by usage and important dates | 2 to 4 replicas under load, and 2 to 3 when a filing window opens | `make load RATE=80 DURATION=5m` |
| Kubecost with its dashboard | Cost by namespace and by service from the platform Prometheus | `make costs-on`, then the Kubecost name |
| ELK for logs in real time | Logs of the five services and Kubernetes events in Kibana within a minute | Kibana, data view PlazoFiscal logs |
| Sign-in stronger than a password | Every tool and the application ask for a password and an authenticator code | Any name under `plazofiscal.localhost:8000` |
| Dashboard with metrics, logs, traces, events and alerts for the business | The PlazoFiscal dashboard opens first in Grafana | Grafana name |
| Documentation and business case | Business case, architecture, operations and this index | `docs/` |

## 2. Points of the course

### Application, network policies and storage

The five services and Redis run in `plazofiscal`, which starts from default deny. `make check-policies` opens every allowed path from the real pods and tries every closed one, 31 paths in all, and fails on any difference. With one policy removed on purpose, it reported exactly the two paths that policy opened. Obligations kept the same list after a Redis pod restart, which came back in 12 seconds on the node that holds its volume.

### Rolling deployment

Each service starts one new pod, waits for it to be ready and only then removes an old one. Under accountant traffic at 15 requests per second, the release of `todos-api` and `frontend` served 4117 requests with no failure, p95 15.9 ms, and the release of `auth-api` and `users-api` served 5155 with no failure, p95 12.8 ms. Before the services handled the shutdown signal and waited for the endpoints to update, the same test failed 6 requests during the release of the frontend.

### Autoscaling by usage and dates

KEDA combines CPU with two calendar windows of the business. At 92 requests per second, the three scaled services reached 4 replicas with no failed request and no pod waiting for room, and returned to 2 after the load. A calendar window moved to the next minutes raised the obligations service from 2 to 3 replicas as it opened, and back to 2 five minutes after it closed.

### Costs

Kubecost 2.8 reads the platform Prometheus and shows cost by namespace and by service from its reference prices. It runs for cost reviews, since the reference machine has no room for every tool at once.

### Logs with ELK

Fluent Bit sends the container logs of `plazofiscal` and the Kubernetes events to Logstash, which names the service, reads the level and drops probes before Elasticsearch stores them for 3 days. Kibana shows both through two data views.

### Sign-in with a second factor

Keycloak requires a password and a six digit code from an authenticator app before any tool or the application opens. The tools also require the group `plataforma`, and a user outside it gets a page to sign in as someone else. A wrong code is refused.

### Business dashboard

The PlazoFiscal dashboard shows obligations registered by tax, obligations overdue and due in 7 days, sign-ins by result and the filing window, next to service health, alerts, logs, traces and events. Signing in and creating an obligation can be followed in Jaeger across the frontend, the services and the activity processor, and the trace id leads to the matching log line in Kibana. An alert fired with the users service at zero replicas, reached Slack within two minutes and resolved five minutes after the restore.

## 3. Screenshots

| Topic | Files |
|---|---|
| Application | `frontend-sign-in.png`, `frontend-obligations.png`, `frontend-mobile.png` |
| Sign-in | `sign-in-password.png`, `sign-in-code.png`, `sign-in-grafana.png`, `sign-in-app.png`, `sign-in-forbidden-page.png` |
| Business dashboard | `dashboard-plazofiscal.png`, `dashboard-business.png` |
| Metrics and scaling | `grafana-nodes-overview.png`, `grafana-workloads.png`, `grafana-network.png`, `grafana-keda.png` |
| Alerts | `grafana-alert-rule.png`, `alertmanager-firing.png` |
| Logs and events | `kibana-service-logs.png`, `kibana-trace-logs.png`, `kibana-events.png` |
| Traces | `jaeger-sign-in-trace.png`, `jaeger-obligation-trace.png` |
| Costs | `kubecost-allocations.png` |
