# Architecture

This document explains how PlazoFiscal runs on Azure, why the cluster has its size, and how the main decisions fit the capacity available. The business reasons live in the [business case](business-case.md).

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
| AKS | Azure Kubernetes Service |
| Rolling update | A release that replaces pods a few at a time |
| PVC | A request for a persistent disk |
| HPA | The Kubernetes object that changes replicas by load |
| OIDC | A sign-in standard, used here for people and for the pipeline |

## 2. Overview

One AKS cluster holds the application and the operations tools. Traefik receives traffic, and sign-in protects each entry point. No environment split exists, because the platform is a demonstration that lives for hours at a time.

| Namespace | Holds |
|---|---|
| `plazofiscal` | Application and Redis |
| `ingress` | Traefik |
| `identity` | Keycloak and oauth2-proxy |
| `observability` | Prometheus, Alertmanager, Grafana, Jaeger, ELK and Kubecost |
| `keda` | Scaling by date and load |

## 3. Capacity

The subscription limits the design more than any other factor.

| Limit | Value |
|---|---|
| Allowed regions | `mexicocentral`, `southcentralus`, `eastus2`, `westus3`, `brazilsouth` |
| vCPU per region | 6, with no increases on this offer |
| Sizes | Vary per region and per zone |

The cluster uses three `Standard_B2as_v2` nodes in `mexicocentral`, the allowed region closest to Colombia. That gives 6 vCPU and 24 GiB. Zones 2 and 3 are set explicitly, because this size is unavailable in zone 1 of that region for this subscription.

These nodes are burstable, with a baseline of 40 percent of CPU and credits to go above it. That suits a demonstration, and sustained load would throttle them. A production service would use general purpose nodes.

| Component | Estimated memory |
|---|---|
| Elasticsearch | 3 GiB |
| Logstash and Kibana | 2 GiB |
| Prometheus, Alertmanager, Grafana and exporters | 2.5 GiB |
| Kubecost | 1 GiB |
| Jaeger and event exporter | 0.5 GiB |
| Keycloak and oauth2-proxy | 1.5 GiB |
| Traefik and KEDA | 0.5 GiB |
| Application at maximum replicas | 2.5 GiB |
| **Total** | **13.5 GiB** |

## 4. Rolling deployment

Each service sets `maxSurge: 1` and `maxUnavailable: 0`. Kubernetes starts one new pod, waits for its readiness probe, and only then removes an old one, so capacity never falls during a release. A PodDisruptionBudget protects the same services when a node is drained. An undo returns to the previous version with the same mechanism.

The extra pod needs room in the cluster, so a release and a scaling event compete for the same capacity. Replica limits leave space for that.

Redis stays outside this strategy. It runs one replica with a persistent disk, so a new version replaces it with a short interruption.

## 5. Storage

Redis persists its data with an append-only file on a managed disk, and the activity processor keeps its log on another. The disks live as long as the cluster, so bringing the platform down erases them. That fits a demonstration, and a production service would add backups.

## 6. Network isolation

The `plazofiscal` namespace starts from default deny, for traffic in both directions. Each policy then opens one path, and Cilium enforces them. No service reaches another unless a policy names that path.

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
| Obligations service | 1 | 4 |

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
| Three small nodes | One larger node | Zones and rolling updates need more than one node |
| Traefik | `ingress-nginx` | `ingress-nginx` is retired and receives no fixes |
| Keycloak | An external identity provider | It works with no dependency on another tenant, at about 1 GiB more |
| Calendar rules through KEDA | A scheduled job that edits the HPA | One declarative object, with no extra permissions |
| One public repository | Several repositories | One change can touch code, manifests and documents |

## 11. Assumptions and pending confirmations

| Item | Who confirms | Effect if it fails |
|---|---|---|
| Azure has capacity for three nodes in those zones | First deployment | Move to `westus3`, zones 1 and 2 |
| The stack fits in 24 GiB and the CPU baseline | First full deployment | Lower replicas or retention |
| The free Kubecost tier covers this cluster | Installation | Use OpenCost, its open source base |
| Kibana can skip its login behind `oauth2-proxy` | Installation | Keep a second login, or read logs in Grafana |
