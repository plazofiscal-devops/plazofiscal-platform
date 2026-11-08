# Operations

This document explains what the platform needs, how to run it day to day, and what to do when something fails.

## Contents

1. Requirements
2. Daily commands
3. Releasing a service
4. Dashboards, logs, traces and alerts
5. Secrets
6. Troubleshooting

## 1. Requirements

| Requirement | Detail |
|---|---|
| Docker | Running, with access for the current user |
| k3d | Version 5.9, the version tested |
| kubectl | Within one minor version of Kubernetes 1.36 |
| Helm | Version 3 |
| Memory | 12 GiB free on the machine, with browsers and other heavy programs closed |
| CPU | 8 cores recommended |

`make` reads `AGENTS`, `SERVER_MEMORY` and `AGENT_MEMORY`, so a smaller machine can try `make up AGENTS=1 AGENT_MEMORY=3g`. With less memory, keep only the tools a demonstration needs.

## 2. Daily commands

| Command | Effect |
|---|---|
| `make up` | Creates the cluster, installs the platform, builds the images and deploys |
| `make platform` | Installs or updates the platform components from their pinned charts |
| `make status` | Shows nodes, pods and resource use |
| `make forward` | Opens the application on `http://localhost:8080` until the command stops |
| `make dashboards` | Opens Grafana, Kubecost, Alertmanager and Prometheus on localhost until the command stops |
| `make load` | Runs accountant traffic inside the cluster and fails if any request fails. `RATE` and `DURATION` set 15 requests per second for 3 minutes by default |
| `make check-policies` | Proves every allowed and denied network path and fails on any difference |
| `make stop` | Pauses the cluster and keeps its data |
| `make down` | Deletes the cluster and its data |

All commands pass the `k3d-plazofiscal` context, so they never touch another cluster of the same machine. Creating the cluster adds that context to kubectl and leaves the current context unchanged, and `make down` removes it.

## 3. Releasing a service

```bash
make rollout SERVICE=todos-api TAG=v2
```

The command builds the image with the Docker of the machine, imports it into the three nodes and starts a rolling update. To prove that a release loses no request, start the load first in another terminal and release while it runs.

```bash
make load DURATION=4m
make rollout SERVICE=frontend TAG=v2
```

The load prints its summary at the end, and `http_req_failed` must read 0.00 percent. To return to the previous version, run this.

```bash
kubectl --context k3d-plazofiscal --namespace plazofiscal rollout undo deployment/todos-api
```

## 4. Dashboards, logs, traces and alerts

Every tool and the application open through the entry point on port 8000, after Keycloak asks for a password and a code. Grafana opens on the PlazoFiscal dashboard, with the business indicators, service health, alerts, logs, traces and events of the platform.

| Name | Address |
|---|---|
| Application | `http://app.plazofiscal.localhost:8000` |
| Grafana | `http://grafana.plazofiscal.localhost:8000` |
| Kibana | `http://kibana.plazofiscal.localhost:8000` |
| Kubecost | `http://kubecost.plazofiscal.localhost:8000` |
| Jaeger | `http://jaeger.plazofiscal.localhost:8000` |
| Alertmanager | `http://alertmanager.plazofiscal.localhost:8000` |
| Prometheus | `http://prometheus.plazofiscal.localhost:8000` |
| Keycloak | `http://auth.plazofiscal.localhost:8000` |

The realm has two demonstration users, each with its name as password. `operador` belongs to the group `plataforma` and opens the tools and the application. `contador` belongs to the group `contadores` and opens only the application, where the accountant then signs in again with the application users, such as `janed`. On the first sign-in, Keycloak shows a QR code. Scan it with an authenticator app such as Google Authenticator, FreeOTP or Aegis, and type the six digit code. Later sign-ins ask for the password and the current code. One sign-in opens every name for 8 hours.

The Keycloak administration console opens at `http://auth.plazofiscal.localhost:8000/admin` with the user `admin` and a generated password.

```bash
kubectl --context k3d-plazofiscal --namespace identity get secret sso \
  --output jsonpath='{.data.keycloak-admin-password}' | base64 --decode
```

To reset the authenticator of a user, open the console, choose the realm `plazofiscal`, then the user, and delete its OTP credential under Credentials. The realm file is imported on the first start only, so a change to `deploy/platform/keycloak/realm.json` needs the realm deleted in the console before Keycloak restarts.

Kubecost stays off in daily use, since the machine has no room for every tool at once. `make costs-on` starts it for a cost review, and `make costs-off` stops it. Its figures come from Prometheus, which keeps 7 days, so it shows the recent cost when it starts.

For operators with cluster credentials, `make dashboards` also forwards each tool to the machine.

| Tool | Address |
|---|---|
| Grafana | `http://localhost:3000` |
| Kubecost | `http://localhost:9090` |
| Alertmanager | `http://localhost:9093` |
| Prometheus | `http://localhost:9091` |
| Kibana | `http://localhost:5601` |
| Jaeger | `http://localhost:16686` |

Through the port forward, Kibana asks for the user `admin` with the password `admin`, and Grafana sends the browser to Keycloak. Grafana keeps the local `admin` with password `admin` at `http://localhost:3000/login?disableAutoLogin`. When a pod of a tool is replaced, its forward stops, so run `make dashboards` again.

Kibana opens on the data view PlazoFiscal logs, with one line per log entry and the service in `service.name`. The data view Kubernetes events lists events with their reason, type and object. Logs and events are kept for 3 days.

To follow one request, sign in on the application and create an obligation, then open Jaeger, choose the service `log-message-processor` and open the latest trace. It shows the frontend, the obligations service and the activity processor in order. In Kibana, search for the trace id of that trace to find the line the processor logged for it. Signing in shows a trace through the frontend, the sign-in service and the users service.

Alerts reach Slack through an incoming webhook of the channel. Create the webhook in Slack, save its address in a file that only the current user can read, and run the installation again.

```bash
mkdir -p ~/.config/plazofiscal
install -m 600 /dev/null ~/.config/plazofiscal/alert-webhook
"$EDITOR" ~/.config/plazofiscal/alert-webhook
make platform
```

`ALERT_WEBHOOK_FILE` points the installation to another file. Without the file, the installation says so and alerts stay inside Alertmanager.

To prove the whole path, take the users service down and bring it back. The channel receives the firing message about two minutes later and the resolved message about five minutes after the restore.

```bash
kubectl --context k3d-plazofiscal --namespace plazofiscal scale deployment/users-api --replicas=0
kubectl --context k3d-plazofiscal --namespace plazofiscal scale deployment/users-api --replicas=1
```

Kubecost needs about an hour after installation before its interface shows the first full hour of cost.

## 5. Secrets

The repository holds no secret. The deployment generates the signing key of the application once, and it lives only in the cluster. The Grafana and Kibana accounts `admin` with password `admin` are a known local default, reachable only through the port forward. The Slack webhook address lives in a file of the machine outside the repository and in a Secret of the cluster.

## 6. Troubleshooting

| Symptom | Cause | Response |
|---|---|---|
| Pods in `Pending` | The cluster has no memory left | Run `make status`, then reduce replicas or stop a tool |
| A name under `plazofiscal.localhost` does not open | The cluster was created before the entry point existed, so k3d maps no port 8000 | Run `k3d cluster edit plazofiscal --port-add 8000:30800@loadbalancer`, or `make down` and `make up` |
| Keycloak asks for a code the app does not show | The authenticator was enrolled on another phone | Reset the OTP credential of the user in the Keycloak console |
| A tool shows Sin acceso a esta herramienta | The user is not in the group `plataforma` | Press Cerrar sesión y entrar con otro usuario and sign in as `operador`, or add the user to the group in the console |
| Many pods restart at once and the forwards stop | The machine ran short of memory and a node restarted its components | Close heavy programs, wait until `make status` shows every pod ready, and run `make dashboards` again |
| Fluent Bit restarts with `Too many open files` | The machine reached its inotify limit | The configuration polls files, so this only appears with a changed configuration. Raise `fs.inotify.max_user_instances` on the machine |
| Kibana restarts with `JavaScript heap out of memory` | Its Node heap is too small for the version | Keep `--max-old-space-size` at 1024 or more in `deploy/platform/elastic/kibana.yaml` |
| Pods in `OOMKilled` | A tool exceeded its limit | Raise its limit inside the budget of the architecture document |
| The machine freezes | Too much memory assigned | Run `make stop`, close programs, and try again with a lower `MEMORY` |
| Traffic between services is blocked | A network policy has no matching path | Run `make check-policies` to see which path fails, then read `deploy/policies/network-policies.yaml` and add the path |
| A Grafana panel about node memory shows no data | k3d replaces the memory file of each node, so node exporter has no memory figures | Read node memory in the Nodes Overview and Node dashboards, which come from the kubelet |
| No alert reaches Slack | The webhook file is missing or the address expired | Check that `~/.config/plazofiscal/alert-webhook` exists, then run `make platform`. Alertmanager counts failed sends in `alertmanager_notifications_failed_total` |
| A service keeps the old image | The tag did not change | Use a new `TAG` on each release |
| `make up` waits after `make stop` | Docker can give a node a new address on restart, and K3s restarts the node until it settles | Wait, since `make up` continues once every node is ready. If five minutes pass, run `make down` and `make up`, which erases the data |
| `make load` fails at once with `connection refused` | The network policies have not yet registered the load test pod | The load waits for the frontend before it starts. If it still fails, run it again |
| A service logs `waiting for redis` at start | Redis is starting, or the network policies have not yet registered the new pod | Nothing, since the services retry the connection |
