# Operations

This document explains what the platform needs, how to run it day to day, and what to do when something fails.

## Contents

1. Requirements
2. Daily commands
3. Releasing a service
4. Secrets
5. Troubleshooting

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

## 4. Secrets

The repository holds no secret. The deployment generates the signing key of the application once, and it lives only in the cluster.

## 5. Troubleshooting

| Symptom | Cause | Response |
|---|---|---|
| Pods in `Pending` | The cluster has no memory left | Run `make status`, then reduce replicas or stop a tool |
| Pods in `OOMKilled` | A tool exceeded its limit | Raise its limit inside the budget of the architecture document |
| The machine freezes | Too much memory assigned | Run `make stop`, close programs, and try again with a lower `MEMORY` |
| Traffic between services is blocked | A network policy has no matching path | Run `make check-policies` to see which path fails, then read `deploy/policies/network-policies.yaml` and add the path |
| A service keeps the old image | The tag did not change | Use a new `TAG` on each release |
| `make up` waits after `make stop` | Docker can give a node a new address on restart, and K3s restarts the node until it settles | Wait, since `make up` continues once every node is ready. If five minutes pass, run `make down` and `make up`, which erases the data |
| `make load` fails at once with `connection refused` | The network policies have not yet registered the load test pod | The load waits for the frontend before it starts. If it still fails, run it again |
| A service logs `waiting for redis` at start | Redis is starting, or the network policies have not yet registered the new pod | Nothing, since the services retry the connection |
