PROFILE ?= plazofiscal
CPUS ?= 6
MEMORY ?= 10240
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
	minikube start --profile $(PROFILE) --driver=docker --cni=cilium \
		--cpus=$(CPUS) --memory=$(MEMORY) --addons=metrics-server

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
	minikube stop --profile $(PROFILE)

down:
	minikube delete --profile $(PROFILE)
