#!/usr/bin/env bash
# Runs the k6 load test as a Job inside the cluster and prints its summary.
# Exits with the result of the k6 thresholds.
set -euo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
rate=${1:-15}
duration=${2:-3m}
kube() { kubectl --context "$context" --namespace plazofiscal "$@"; }

kube apply --kustomize deploy/load >/dev/null
kube delete job load-test --ignore-not-found --wait >/dev/null

kube apply --filename - >/dev/null <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: load-test
    spec:
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 12345
      initContainers:
        # A new pod can be refused for a few seconds until the network policies include it.
        - name: wait-for-frontend
          image: grafana/k6:2.3.0
          command: ["sh", "-c", "until wget -q -O /dev/null http://frontend:8080/; do sleep 2; done"]
      containers:
        - name: k6
          image: grafana/k6:2.3.0
          args: ["run", "--quiet", "/scripts/accountants.js"]
          env:
            - name: RATE
              value: "$rate"
            - name: DURATION
              value: "$duration"
          volumeMounts:
            - name: script
              mountPath: /scripts
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { cpu: 1000m, memory: 384Mi }
      volumes:
        - name: script
          configMap:
            name: load-test-script
YAML

echo "Load test running at $rate requests per second for $duration"
kube wait --for=condition=Ready pod --selector job-name=load-test --timeout=120s >/dev/null || true
kube logs --follow job/load-test --container k6 || true

until status=$(kube get job load-test --output jsonpath='{.status.succeeded}{.status.failed}') && [ -n "$status" ]; do
  sleep 2
done
[ "$(kube get job load-test --output jsonpath='{.status.succeeded}')" = "1" ]
