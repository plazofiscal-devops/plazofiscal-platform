# PlazoFiscal Platform

PlazoFiscal helps accounting firms in Colombia track the tax obligations of their clients, so that no deadline passes unnoticed. This repository holds the application, the infrastructure on Azure, the Kubernetes deployment and the documents of the platform.

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
| Controlled cost | The platform exists only while someone uses it, and it comes down each night |

## Repository layout

```text
app/                 Five services, based on an open source microservice example
infra/bootstrap/     One-time setup of identity and state
infra/terraform/     AKS cluster
deploy/app/          Application manifests with rolling updates
deploy/policies/     Network policies
deploy/autoscaling/  Scaling rules by load and date
deploy/platform/     Observability, costs and sign-in
docs/                Business case, architecture and operations
```

## Documents

| Document | Content |
|---|---|
| [Business case](docs/business-case.md) | The company, its customers, its calendar and its objectives |
| [Architecture](docs/architecture.md) | Components, capacity and the main decisions |
| [Operations](docs/operations.md) | First setup, bringing the platform up and down, access and cost |

## Run the platform

The platform starts from GitHub Actions, with a person's approval, and no one needs the Azure account or a stored credential. [Operations](docs/operations.md) explains the access model.

| Workflow | Effect |
|---|---|
| Platform up | Creates the cluster and deploys everything, after approval |
| Deploy application | Starts a rolling update of one service |
| Platform down | Removes the cluster, on demand and each night |

## Credits

The services in `app/` come from an MIT licensed microservice example, and `app/LICENSE` keeps its notice.
