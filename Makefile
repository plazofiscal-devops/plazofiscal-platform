CLUSTER ?= plazofiscal
CONTEXT := k3d-$(CLUSTER)
K3S_IMAGE ?= rancher/k3s:v1.36.6-k3s1
AGENTS ?= 2
SERVER_MEMORY ?= 3g
AGENT_MEMORY ?= 3.5g
TAG ?= local
RATE ?= 15
DURATION ?= 3m
SERVICES := auth-api users-api todos-api frontend log-message-processor

.DEFAULT_GOAL := help
.PHONY: help up cluster platform images deploy status forward dashboards load check-policies rollout stop down

help:
	@printf '%s\n' \
		'make up                              Create the cluster, install the platform, build the images and deploy' \
		'make status                          Show nodes, pods and resource use' \
		'make forward                         Open the application on http://localhost:8080' \
		'make dashboards                      Open Grafana, Kubecost, Alertmanager and Prometheus on localhost' \
		'make load RATE=15 DURATION=3m        Run accountant traffic inside the cluster' \
		'make check-policies                  Prove every allowed and denied network path' \
		'make rollout SERVICE=todos-api TAG=v2  Build one image and start a rolling update' \
		'make stop                            Pause the cluster and keep its data' \
		'make down                            Delete the cluster and its data'

up: cluster platform images deploy

cluster:
	@if k3d cluster list $(CLUSTER) >/dev/null 2>&1; then \
		k3d cluster start $(CLUSTER) --wait; \
	else \
		k3d cluster create $(CLUSTER) --servers 1 --agents $(AGENTS) --image $(K3S_IMAGE) \
			--servers-memory $(SERVER_MEMORY) --agents-memory $(AGENT_MEMORY) \
			--k3s-arg '--disable=traefik@server:0' --k3s-arg '--disable=servicelb@server:0' \
			--kubeconfig-switch-context=false --wait; \
	fi
	bash deploy/wait-for-nodes.sh $(CLUSTER)

platform:
	KUBE_CONTEXT=$(CONTEXT) bash deploy/platform/install.sh

images:
	@for service in $(SERVICES); do \
		docker build --tag plazofiscal/$$service:$(TAG) app/$$service || exit 1; \
	done
	k3d image import --cluster $(CLUSTER) $(foreach service,$(SERVICES),plazofiscal/$(service):$(TAG))

deploy:
	KUBE_CONTEXT=$(CONTEXT) bash deploy/up.sh

status:
	kubectl --context $(CONTEXT) get nodes --output wide
	kubectl --context $(CONTEXT) get pods --all-namespaces
	@kubectl --context $(CONTEXT) top nodes 2>/dev/null || echo 'Resource use is not available yet. Try again in a minute.'

forward:
	kubectl --context $(CONTEXT) --namespace plazofiscal port-forward service/frontend 8080:8080

dashboards:
	KUBE_CONTEXT=$(CONTEXT) bash deploy/dashboards.sh

load:
	KUBE_CONTEXT=$(CONTEXT) bash deploy/load/run.sh $(RATE) $(DURATION)

check-policies:
	KUBE_CONTEXT=$(CONTEXT) bash deploy/policies/check.sh

rollout:
	@test -n "$(SERVICE)" || { echo 'Set SERVICE, for example SERVICE=todos-api'; exit 2; }
	docker build --tag plazofiscal/$(SERVICE):$(TAG) app/$(SERVICE)
	k3d image import --cluster $(CLUSTER) plazofiscal/$(SERVICE):$(TAG)
	kubectl --context $(CONTEXT) --namespace plazofiscal set image deployment/$(SERVICE) $(SERVICE)=plazofiscal/$(SERVICE):$(TAG)
	kubectl --context $(CONTEXT) --namespace plazofiscal rollout status deployment/$(SERVICE) --timeout=10m

stop:
	k3d cluster stop $(CLUSTER)

down:
	k3d cluster delete $(CLUSTER)
