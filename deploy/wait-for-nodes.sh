#!/usr/bin/env bash
# Waits until every node is ready and no node container is restarting.
# After a restart, Docker may give a node a new address, and K3s restarts until it settles.
# https://github.com/k3d-io/k3d/issues/1637
set -euo pipefail

cluster=${1:?pass the cluster name}
stable=0
previous=

for _ in $(seq 1 60); do
  current=$(docker ps --all --quiet --filter "label=k3d.cluster=$cluster" |
    xargs docker inspect --format '{{.Name}} {{.RestartCount}} {{.State.Status}}' | sort)
  if [ "$current" = "$previous" ] && ! grep --quiet --invert-match ' running$' <<<"$current" &&
    kubectl --context "k3d-$cluster" wait --for=condition=Ready node --all --timeout=5s >/dev/null 2>&1; then
    stable=$((stable + 1))
    if [ "$stable" -ge 3 ]; then
      echo "All nodes of $cluster are ready"
      exit 0
    fi
  else
    stable=0
  fi
  previous=$current
  sleep 5
done

echo "The nodes of $cluster did not settle within five minutes" >&2
exit 1
