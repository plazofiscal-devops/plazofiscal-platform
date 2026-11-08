#!/usr/bin/env bash
# Proves the network policies of the plazofiscal namespace, path by path.
# Allowed paths run from the real pods, since a probe pod with an app label would join that service.
# Each denied path targets a port that an allowed path reaches, so a refusal can only come from a policy.
# Exits non-zero when any path behaves differently from what the policies declare.
set -uo pipefail

context=${KUBE_CONTEXT:?set KUBE_CONTEXT to the cluster context}
kube() { kubectl --context "$context" "$@"; }
probe_image=busybox:1.37.0
created_ingress=false
failures=0

cleanup() {
  kube --namespace plazofiscal delete pod policy-probe --ignore-not-found --wait=false >/dev/null
  kube --namespace default delete pod policy-probe --ignore-not-found --wait=false >/dev/null
  kube --namespace observability delete pod policy-probe --ignore-not-found --wait=false >/dev/null
  if [ "$created_ingress" = true ]; then
    kube delete namespace ingress --wait=false >/dev/null
  else
    kube --namespace ingress delete pod policy-probe --ignore-not-found --wait=false >/dev/null
  fi
}
trap cleanup EXIT

pod_of() {
  kube --namespace plazofiscal get pods --selector "app=$1" --field-selector status.phase=Running \
    --output jsonpath='{.items[0].metadata.name}'
}

ip_of() {
  kube --namespace plazofiscal get service "$1" --output jsonpath='{.spec.clusterIP}'
}

# connects <namespace> <pod> <ip> <port> succeeds when a TCP connection opens within 3 seconds.
connects() {
  local namespace=$1 pod=$2 ip=$3 port=$4
  if [ "$pod" = "$processor" ]; then
    kube --namespace "$namespace" exec "$pod" -- python -c \
      "import socket; socket.create_connection(('$ip', $port), 3)" >/dev/null 2>&1
  else
    kube --namespace "$namespace" exec "$pod" -- nc -z -w 3 "$ip" "$port" >/dev/null 2>&1
  fi
}

# expect <allow|deny> <description> <namespace> <pod> <ip> <port>
expect() {
  local want=$1 description=$2 got=deny
  shift 2
  if connects "$@"; then
    got=allow
  elif [ "$want" = allow ]; then
    # A pod can be refused for a few seconds until the policy controller includes it.
    sleep 5
    connects "$@" && got=allow
  fi
  if [ "$got" = "$want" ]; then
    printf '%-6s %-6s %s\n' ok "$want" "$description"
  else
    printf '%-6s %-6s %s, got %s\n' FAIL "$want" "$description" "$got"
    failures=$((failures + 1))
  fi
}

start_probe() {
  local namespace=$1
  shift
  kube --namespace "$namespace" run policy-probe --image "$probe_image" --restart Never "$@" \
    --command -- sleep 600 >/dev/null
}

if ! kube get namespace ingress >/dev/null 2>&1; then
  kube create namespace ingress >/dev/null
  created_ingress=true
fi
start_probe plazofiscal
start_probe default
start_probe ingress
start_probe observability
for namespace in plazofiscal default ingress observability; do
  kube --namespace "$namespace" wait --for=condition=Ready pod/policy-probe --timeout=120s >/dev/null
done

frontend=$(pod_of frontend)
auth=$(pod_of auth-api)
users=$(pod_of users-api)
todos=$(pod_of todos-api)
redis=$(pod_of redis-queue)
processor=$(pod_of log-message-processor)

frontend_ip=$(ip_of frontend)
auth_ip=$(ip_of auth-api)
users_ip=$(ip_of users-api)
todos_ip=$(ip_of todos-api)
redis_ip=$(ip_of redis-queue)
api_ip=$(kube --namespace default get service kubernetes --output jsonpath='{.spec.clusterIP}')

echo "Result Expect Path"
echo "Allowed paths"
expect allow "ingress namespace -> frontend 8080" ingress policy-probe "$frontend_ip" 8080
expect allow "frontend -> auth-api 8081" plazofiscal "$frontend" "$auth_ip" 8081
expect allow "frontend -> todos-api 8082" plazofiscal "$frontend" "$todos_ip" 8082
expect allow "auth-api -> users-api 8083" plazofiscal "$auth" "$users_ip" 8083
expect allow "todos-api -> redis 6379" plazofiscal "$todos" "$redis_ip" 6379
expect allow "log-message-processor -> redis 6379" plazofiscal "$processor" "$redis_ip" 6379
if kube --namespace plazofiscal exec "$todos" -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
  printf '%-6s %-6s %s\n' ok allow "todos-api -> cluster DNS 53"
else
  printf '%-6s %-6s %s, got deny\n' FAIL allow "todos-api -> cluster DNS 53"
  failures=$((failures + 1))
fi

echo "Denied between services"
expect deny "frontend -> users-api 8083" plazofiscal "$frontend" "$users_ip" 8083
expect deny "frontend -> redis 6379" plazofiscal "$frontend" "$redis_ip" 6379
expect deny "auth-api -> todos-api 8082" plazofiscal "$auth" "$todos_ip" 8082
expect deny "auth-api -> redis 6379" plazofiscal "$auth" "$redis_ip" 6379
expect deny "todos-api -> auth-api 8081" plazofiscal "$todos" "$auth_ip" 8081
expect deny "todos-api -> users-api 8083" plazofiscal "$todos" "$users_ip" 8083
expect deny "users-api -> redis 6379" plazofiscal "$users" "$redis_ip" 6379
expect deny "users-api -> todos-api 8082" plazofiscal "$users" "$todos_ip" 8082
expect deny "log-message-processor -> todos-api 8082" plazofiscal "$processor" "$todos_ip" 8082
expect deny "redis -> frontend 8080" plazofiscal "$redis" "$frontend_ip" 8080

echo "Denied from outside the allowed sources"
expect deny "unlabeled pod in plazofiscal -> frontend 8080" plazofiscal policy-probe "$frontend_ip" 8080
expect deny "unlabeled pod in plazofiscal -> redis 6379" plazofiscal policy-probe "$redis_ip" 6379
expect deny "pod in default -> frontend 8080" default policy-probe "$frontend_ip" 8080
expect deny "pod in default -> todos-api 8082" default policy-probe "$todos_ip" 8082
expect deny "ingress namespace -> todos-api 8082" ingress policy-probe "$todos_ip" 8082
expect deny "ingress namespace -> redis 6379" ingress policy-probe "$redis_ip" 6379
expect deny "observability namespace -> todos-api 8082" observability policy-probe "$todos_ip" 8082
expect deny "observability namespace -> redis 6379" observability policy-probe "$redis_ip" 6379

echo "Controls, the same destinations answer a pod in default, which has no policies"
expect allow "pod in default -> internet 1.1.1.1 443" default policy-probe 1.1.1.1 443
expect allow "pod in default -> Kubernetes API 443" default policy-probe "$api_ip" 443

echo "Denied egress"
expect deny "todos-api -> internet 1.1.1.1 443" plazofiscal "$todos" 1.1.1.1 443
expect deny "todos-api -> Kubernetes API 443" plazofiscal "$todos" "$api_ip" 443
expect deny "frontend -> internet 1.1.1.1 443" plazofiscal "$frontend" 1.1.1.1 443

if [ "$failures" -eq 0 ]; then
  echo "Every path matches the policies"
else
  echo "$failures paths do not match the policies" >&2
  exit 1
fi
