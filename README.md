# PlazoFiscal Platform

PlazoFiscal helps accounting firms in Colombia track the tax obligations of their clients, so that no deadline passes unnoticed. This repository holds the application, its Kubernetes deployment and the documents of the platform, which runs on a local Kubernetes cluster of three nodes.

PlazoFiscal is an invented company for an academic exercise. It has no link with any tax authority, and its figures are assumptions.

## What it demonstrates

| Capability | How the platform delivers it |
|---|---|
| Rolling deployment | One extra pod at a time, no pod removed until its replacement is ready |
| Network isolation | Default deny, with each allowed path declared |
| Persistent storage | Redis keeps obligations on a persistent volume |
| Autoscaling | CPU load, plus rules for the filing dates of the business |
| Cost visibility | Kubecost, by namespace and service |
| Centralized logs | Elasticsearch, Logstash and Kibana |
| Metrics, traces, events and alerts | Prometheus, Jaeger, Kubernetes events and Alertmanager, in one Grafana dashboard |
| Strong sign-in | Keycloak with a required second factor |
| One command operation | `make up` builds and deploys everything, and `make down` removes it |

## Repository layout

```text
app/                 Five services, based on an open source microservice example
deploy/app/          Application manifests with rolling updates
deploy/policies/     Network policies
deploy/autoscaling/  Scaling rules by load and date
deploy/platform/     Observability, costs and sign-in
docs/                Business case, architecture and operations
Makefile             Commands to run the platform
```

## Documents

| Document | Content |
|---|---|
| [Business case](docs/business-case.md) | The company, its customers, its calendar and its objectives |
| [Architecture](docs/architecture.md) | Components, capacity and the main decisions |
| [Operations](docs/operations.md) | Requirements, daily commands and troubleshooting |

## Run the platform

You need Docker, k3d and kubectl. The platform is sized for a machine with 8 cores and 13.5 GiB of memory, and the cluster is capped at 10 GiB. Close browsers and other heavy programs before starting it.

```bash
make up
make status
make forward
make down
```

`make up` creates the cluster, installs the platform components, builds the images and deploys the application. The first run takes several minutes while it downloads and builds the images, and later runs take about two to four minutes. `make forward` opens the application on `http://localhost:8080`.

[Operations](docs/operations.md) lists every command and what to do when memory runs short.

## Credits

The services in `app/` come from an MIT licensed microservice example, and `app/LICENSE` keeps its notice.
