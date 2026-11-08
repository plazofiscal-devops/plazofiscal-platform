CLUSTER ?= plazofiscal
CONTEXT := k3d-$(CLUSTER)
K3S_IMAGE ?= rancher/k3s:v1.36.6-k3s1
AGENTS ?= 2
SERVER_MEMORY ?= 3g
AGENT_MEMORY ?= 3.5g
TAG ?= local
SERVICES := auth-api users-api todos-api frontend log-message-processor

.DEFAULT_GOAL := help
.PHONY: help up cluster images deploy status rollout stop down

help:
	@printf '%s\n' \
		'make up                              Create the cluster, build the images and deploy' \
		'make status                          Show nodes, pods and resource use' \
		'make rollout SERVICE=todos-api TAG=v2  Build one image and start a rolling update' \
		'make stop                            Pause the cluster and keep its data' \
		'make down                            Delete the cluster and its data'

up: cluster images deploy

cluster:
	@if k3d cluster list $(CLUSTER) >/dev/null 2>&1; then \
		k3d cluster start $(CLUSTER) --wait; \
	else \
		k3d cluster create $(CLUSTER) --servers 1 --agents $(AGENTS) --image $(K3S_IMAGE) \
			--servers-memory $(SERVER_MEMORY) --agents-memory $(AGENT_MEMORY) \
			--k3s-arg '--disable=traefik@server:0' --k3s-arg '--disable=servicelb@server:0' \
			--kubeconfig-switch-context=false --wait; \
	fi

images:
	@for service in $(SERVICES); do \
		minikube --profile $(PROFILE) image build --tag plazofiscal/$$service:$(TAG) app/$$service || exit 1; \
	done

deploy:
	KUBE_CONTEXT=$(PROFILE) bash deploy/up.sh

status:
	kubectl --context $(PROFILE) get nodes
	kubectl --context $(PROFILE) get pods --all-namespaces
	kubectl --context $(PROFILE) top nodes

rollout:
	@test -n "$(SERVICE)" || { echo 'Set SERVICE, for example SERVICE=todos-api'; exit 2; }
	minikube --profile $(PROFILE) image build --tag plazofiscal/$(SERVICE):$(TAG) app/$(SERVICE)
	kubectl --context $(PROFILE) --namespace plazofiscal set image deployment/$(SERVICE) $(SERVICE)=plazofiscal/$(SERVICE):$(TAG)
	kubectl --context $(PROFILE) --namespace plazofiscal rollout status deployment/$(SERVICE) --timeout=10m

stop:
	k3d cluster stop $(CLUSTER)

down:
	k3d cluster delete $(CLUSTER)
