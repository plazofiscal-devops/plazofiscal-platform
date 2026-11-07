# Architecture

This document explains how PlazoFiscal runs on a local minikube cluster, why the cluster has its size, and how the main decisions fit the capacity available. The business reasons live in the [business case](business-case.md).

## Contents

1. Terms
2. Overview
3. Capacity
4. Rolling deployment
5. Storage
6. Network isolation
7. Autoscaling
8. Observability
9. Sign-in
10. Decisions and alternatives
11. Assumptions and pending confirmations

## 1. Terms

| Term | Meaning |
|---|---|
| minikube | A Kubernetes cluster that runs on one machine |
| Rolling update | A release that replaces pods a few at a time |
| PVC | A request for a persistent disk |
| HPA | The Kubernetes object that changes replicas by load |
| OIDC | A sign-in standard, used here for people and for the pipeline |

## 2. Overview

One minikube cluster holds the application and the operations tools. It uses the Docker driver, one node and Cilium as network plugin. Traefik receives traffic, and sign-in protects each entry point. The platform has no cloud dependency, so any machine with enough memory can run it from a clean clone.

| Namespace | Holds |
|---|---|
| `plazofiscal` | Application and Redis |
| `ingress` | Traefik |
| `identity` | Keycloak and oauth2-proxy |
| `observability` | Prometheus, Alertmanager, Grafana, Jaeger, ELK and Kubecost |
| `keda` | Scaling by date and load |

## 3. Capacity

Memory limits the design more than any other factor. The reference machine has 8 cores and 13.5 GiB, so the cluster receives 6 CPUs and 10 GiB and leaves the rest to the operating system. Each tool runs one replica with reduced memory.

| Component | Estimated memory |
|---|---|
| Kubernetes, Cilium and metrics server | 1.3 GiB |
| Elasticsearch | 1.5 GiB |
| Logstash and Kibana | 1.3 GiB |
| Prometheus, Alertmanager, Grafana and exporters | 1.1 GiB |
| Kubecost | 0.6 GiB |
| Jaeger and event exporter | 0.2 GiB |
| Keycloak and oauth2-proxy | 0.8 GiB |
| Traefik and KEDA | 0.3 GiB |
| Application at maximum replicas | 1.8 GiB |
| **Total** | **8.9 GiB** |

The cluster runs one node. The default storage of minikube does not handle several nodes well, and one node leaves more memory for the workload. A production service would run several nodes across zones.

## 4. Rolling deployment

Each service sets `maxSurge: 1` and `maxUnavailable: 0`. Kubernetes starts one new pod, waits for its readiness probe, and only then removes an old one, so capacity never falls during a release. A PodDisruptionBudget declares the same limit for planned disruptions, which matters as soon as the platform has more than one node. An undo returns to the previous version with the same mechanism.

The extra pod needs room in the cluster, so a release and a scaling event compete for the same capacity. Replica limits leave space for that.

Redis stays outside this strategy. It runs one replica with a persistent disk, so a new version replaces it with a short interruption.

## 5. Storage

Redis persists its data with an append-only file on a persistent volume, and the activity processor keeps its log on another. minikube provides those volumes from a folder of the node. Data survives pod restarts and `make stop`, and `make down` erases it. A production service would use managed disks and backups.

## 6. Network isolation

The `plazofiscal` namespace starts from default deny, for traffic in both directions. Each policy then opens one path, and Cilium enforces them. The default network plugin of minikube would accept the policies without enforcing them, so the cluster starts with Cilium. No service reaches another unless a policy names that path.

| From | To | Port |
|---|---|---|
| Traefik | Frontend | 8080 |
| Frontend | Sign-in service and obligations service | 8081, 8082 |
| Sign-in service | Users service | 8083 |
| Obligations service and activity processor | Redis | 6379 |
| Observability namespace | Each pod | Metrics |
| Each pod | Trace collector | 9411 |

## 7. Autoscaling

KEDA creates one HPA per service, combining CPU load at 65 percent with the calendar of the business. The `users-api` service stays fixed, because it uses a seeded database inside each pod, and the activity processor stays at one replica, because it writes to a single disk.

| Service | Minimum | Maximum |
|---|---|---|
| Frontend | 1 | 3 |
| Sign-in service | 1 | 3 |
| Obligations service | 1 | 3 |

## 8. Observability

One Grafana dashboard joins the five signals with the business indicators.

| Signal | Source | Storage |
|---|---|---|
| Metrics | Prometheus | Prometheus |
| Logs | Logstash | Elasticsearch |
| Traces | Services through Zipkin format, received by Jaeger | Elasticsearch |
| Events | Kubernetes event exporter | Elasticsearch |
| Alerts | Prometheus rules | Alertmanager |

Kubecost reads the same Prometheus, so the cluster runs one metrics server.

## 9. Sign-in

Keycloak requires a password and a one-time code. Grafana connects to it directly through OIDC. Kibana and Kubecost have no free SSO, so `oauth2-proxy` protects them at Traefik and sends each person through Keycloak first.

## 10. Decisions and alternatives

| Decision | Alternative | Why this one |
|---|---|---|
| minikube on one node | A managed cloud cluster | It costs nothing and any member of the team can run it |
| Cilium | The default network plugin | It enforces network policies |
| Traefik | `ingress-nginx` | `ingress-nginx` is retired and receives no fixes |
| Keycloak | An external identity provider | It works with no outside dependency, at about 0.8 GiB |
| Calendar rules through KEDA | A scheduled job that edits the HPA | One declarative object, with no extra permissions |
| One public repository | Several repositories | One change can touch code, manifests and documents |

## 11. Assumptions and pending confirmations

| Item | Who confirms | Effect if it fails |
|---|---|---|
| The stack fits in 10 GiB | First full deployment | Reduce retention, then remove Logstash from the path and keep Elasticsearch and Kibana |
| Kubecost shows useful figures on a local cluster with default prices | Installation | Use OpenCost, its open source base |
| Kibana can skip its login behind `oauth2-proxy` | Installation | Keep a second login, or read logs in Grafana |

## Prices in Kubecost

A local cluster has no bill, so Kubecost estimates from its default reference prices. Its figures show how cost would divide across services, and they describe no real invoice. The free tier covers up to 250 cores and keeps 15 days of metrics, which fits this cluster. Custom prices belong to its paid tier.
