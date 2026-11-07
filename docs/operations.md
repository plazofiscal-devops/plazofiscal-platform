# Operations

This document explains how to prepare the platform, how to bring it up and down, who can do it, and what it costs.

## Contents

1. Access model
2. First setup
3. Daily use
4. Cost
5. Troubleshooting

## 1. Access model

No person or file holds a credential for Azure. The pipeline signs in through OIDC, as a managed identity that trusts only two GitHub environments of this repository.

| Control | Effect |
|---|---|
| Federated identity | GitHub receives a short token for each run, and no secret exists to steal |
| Scope of the identity | One resource group and its state storage, with no access to the rest of the subscription |
| `azure-up` environment | Only `main`, and a named reviewer must approve |
| `azure-down` environment | Only `main`, with no approval, so that the nightly shutdown can run |
| Repository permissions | Only members with write access can start a workflow, and changes to `main` need a reviewed pull request |
| Cluster credentials | Exist on the runner during one run and disappear with it |
| Application secrets | Generated at deployment, and they live only in the cluster |

The Azure identifiers stay in environment secrets, so the logs of this public repository hide them.

## 2. First setup

The subscription owner runs this once.

```bash
az login
gh auth login
ALERT_EMAIL=name@example.com infra/bootstrap/bootstrap.sh
```

The script creates the resource group, the state storage, the identity, the two GitHub environments and a budget with alerts. It is safe to review before running, and bringing the platform down leaves all of this in place.

## 3. Daily use

| Task | Action |
|---|---|
| Start working | Run `Platform up`, and a reviewer approves it |
| Release a service | Run `Deploy application` with the service and the image tag |
| Stop working | Run `Platform down` |
| Forget to stop | The nightly run at 23:00 in Bogota removes the cluster |

## 4. Cost

| Item | Rate, USD per hour |
|---|---|
| Three `Standard_B2as_v2` nodes in `mexicocentral` | 0.248 |
| AKS control plane, free tier | 0 |
| Disks, load balancer and public address, estimated | 0.05 |
| **Total, estimated** | **0.30** |

| Use | Cost, USD |
|---|---|
| A work session of 4 hours | 1.20 |
| One whole day, forgotten | 7.20 |
| Hours that USD 100 covers | About 330 |

The resource group alone holds the identity and a small storage account, which cost almost nothing.

## 5. Troubleshooting

| Symptom | Cause | Response |
|---|---|---|
| `RequestDisallowedByAzure` | The region is outside the subscription policy | Use one of the five allowed regions |
| A size is not available | Sizes are restricted per region and zone | Read the restrictions of the subscription and adjust the zones |
| Quota exceeded | The subscription allows 6 vCPU per region | Keep nodes at 3 with 2 vCPU each |
| A workflow waits with no progress | It needs the approval of a reviewer | Approve it in the Actions tab |
