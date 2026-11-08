# Architecture

This document explains how PlazoFiscal runs on a local Kubernetes cluster of three nodes, why the cluster has its size, and how the main decisions fit the capacity available. The business reasons live in the [business case](business-case.md).

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
| K3s | A lightweight Kubernetes distribution |
| k3d | A tool that runs each K3s node as a Docker container |
| Rolling update | A release that replaces pods a few at a time |
| PVC | A request for a persistent disk |
| HPA | The Kubernetes object that changes replicas by load |
| OIDC | A sign-in standard, used here for people |

## 2. Overview

One K3s cluster holds the application and the operations tools. k3d runs its three nodes as Docker containers on one machine, with one server that runs the control plane and workloads, and two agents that run workloads. K3s enforces network policies with its embedded controller. The Traefik and load balancer bundled with K3s are disabled, so the platform installs its own Traefik in the `ingress` namespace. Traefik receives traffic, and sign-in protects each entry point. The platform has no cloud dependency, so any machine with enough memory can run it from a clean clone.

| Namespace | Holds |
|---|---|
| `plazofiscal` | Application and Redis |
| `ingress` | Traefik |
| `identity` | Keycloak and oauth2-proxy |
| `observability` | Prometheus, Alertmanager, Grafana, Jaeger, ELK and Kubecost |
| `keda` | Scaling by date and load |

## 3. Capacity

Memory limits the design more than any other factor. The reference machine has 8 cores and 13.5 GiB. k3d caps the server node at 3 GiB and each agent at 3.5 GiB, 10 GiB in total, and leaves the rest to the operating system. The nodes share the CPU with no cap. Each tool runs one replica with reduced memory.

| Component | Estimated memory |
|---|---|
| Kubernetes on three nodes and metrics server | 0.8 GiB |
| Elasticsearch | 1.5 GiB |
| Logstash and Kibana | 1.3 GiB |
| Prometheus, Alertmanager, Grafana and exporters | 1.1 GiB |
| Kubecost | 0.6 GiB |
| Jaeger and event exporter | 0.2 GiB |
| Keycloak and oauth2-proxy | 0.8 GiB |
| Traefik and KEDA | 0.3 GiB |
| Application at maximum replicas | 1.8 GiB |
| **Total** | **8.4 GiB** |

The first row is measured on the reference machine, and the rest are estimates. With only the application running, the three nodes use about 2.0 GiB. The users service takes 1.0 GiB of that, because its Java runtime reserves memory when it starts, and the development server of the frontend takes 0.15 GiB.

The cluster runs three nodes, so a rolling update, a disruption budget and the spread of replicas have a real effect. More nodes would repeat the per node overhead with no gain for the demonstration. A production service would run its nodes across zones, on separate machines.

## 4. Rolling deployment

Each service sets `maxSurge: 1` and `maxUnavailable: 0`. Kubernetes starts one new pod, waits for its readiness probe, and only then removes an old one, so capacity never falls during a release. A PodDisruptionBudget declares the same limit for planned disruptions, so draining one of the three nodes moves pods one at a time. An undo returns to the previous version with the same mechanism.

The extra pod needs room in the cluster, so a release and a scaling event compete for the same capacity. Replica limits leave space for that.

Redis stays outside this strategy. It runs one replica with a persistent disk, so a new version replaces it with a short interruption.

## 5. Storage

Redis persists its data with an append-only file on a persistent volume, and the activity processor keeps its log on another. K3s provides those volumes through its local path provisioner, from a folder of the node where the pod first ran. The volume stays on that node, so Redis and the activity processor always return to it, and they wait if that node is down. Data survives pod restarts and `make stop`, and `make down` erases it. A production service would use managed disks and backups.

The obligations service keeps nothing in its own memory. Each user has a hash in Redis with one field per obligation, and a counter that hands out ids. Those Redis operations are atomic, so any number of replicas share the same data, and a rolling update or a restart loses nothing. The service reports ready only while Redis answers, so a pod that cannot reach it leaves the service without being restarted.

## 6. Network isolation

The `plazofiscal` namespace starts from default deny, for traffic in both directions. Each policy then opens one path, and the policy controller embedded in K3s enforces them. A new pod can be refused for a few seconds until the controller registers it, so the services retry their first connection to Redis. No service reaches another unless a policy names that path.

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
| K3s on three nodes through k3d | A managed cloud cluster, minikube on one node, or kind with Cilium | It costs nothing, anyone with Docker can run it, three nodes give rollouts and disruption budgets a real effect, and k3d caps the memory of each node |
| The policy controller of K3s | Cilium | It enforces network policies with no extra agent on each node |
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
