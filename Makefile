IMG ?= quay.io/openstack-k8s-operators/sg-core:latest

.PHONY: docker-build
docker-build: ## Build container image
	podman build -t ${IMG} -f build/Dockerfile .

.PHONY: docker-push
docker-push: ## Push container image
	podman push ${IMG}
