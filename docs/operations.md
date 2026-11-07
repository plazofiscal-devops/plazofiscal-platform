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
| minikube | Recent stable version |
| kubectl | Close to the cluster version |
| Helm | Version 3 |
| Memory | 12 GiB free on the machine, with browsers and other heavy programs closed |
| CPU | 8 cores recommended |

`make` reads `CPUS` and `MEMORY`, so a smaller machine can try `make up MEMORY=8192`. Below 10 GiB, keep only the tools a demonstration needs.

## 2. Daily commands

| Command | Effect |
|---|---|
| `make up` | Creates the cluster, builds the images and deploys |
| `make status` | Shows nodes, pods and resource use |
| `make stop` | Pauses the cluster and keeps its data |
| `make down` | Deletes the cluster and its data |

All commands use the `plazofiscal` profile and context, so they never touch another cluster of the same machine.

## 3. Releasing a service

```bash
make rollout SERVICE=todos-api TAG=v2
```

The command builds the image inside the cluster and starts a rolling update. To return to the previous version, run this.

```bash
kubectl --context plazofiscal --namespace plazofiscal rollout undo deployment/todos-api
```

## 4. Secrets

The repository holds no secret. The deployment generates the signing key of the application once, and it lives only in the cluster.

## 5. Troubleshooting

| Symptom | Cause | Response |
|---|---|---|
| Pods in `Pending` | The cluster has no memory left | Run `make status`, then reduce replicas or stop a tool |
| Pods in `OOMKilled` | A tool exceeded its limit | Raise its limit inside the budget of the architecture document |
| The machine freezes | Too much memory assigned | Run `make stop`, close programs, and try again with a lower `MEMORY` |
| Traffic between services is blocked | A network policy has no matching path | Read `deploy/policies/network-policies.yaml` and add the path |
| A service keeps the old image | The tag did not change | Use a new `TAG` on each release |
