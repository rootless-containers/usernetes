# Run `make help` to show usage
.DEFAULT_GOAL := help

HOSTNAME ?= $(shell hostname)
# HOSTNAME is the name of the physical host
export HOSTNAME := $(HOSTNAME)

HOST_IP ?= $(shell ip --json route get 1 | jq -r .[0].prefsrc)
NODE_NAME ?= u7s-$(HOSTNAME)
NODE_SUBNET ?= $(shell $(CURDIR)/Makefile.d/node_subnet.sh)
# U7S_HOST_IP is the IP address of the physical host. Accessible from other hosts.
export U7S_HOST_IP := $(HOST_IP)
# U7S_NODE_NAME is the IP address of the Kubernetes node running in Rootless Docker.
# Not accessible from other hosts.
export U7S_NODE_NAME:= $(NODE_NAME)
# U7S_NODE_NAME is the subnet of the Kubernetes node running in Rootless Docker.
# Not accessible from other hosts.
export U7S_NODE_SUBNET := $(NODE_SUBNET)

DOCKER ?= docker
COMPOSE := $(DOCKER) compose
NODE_SERVICE_NAME := $(shell $(COMPOSE) config --services | head -n1)
NODE_SHELL := $(COMPOSE) exec \
	-e U7S_HOST_IP=$(U7S_HOST_IP) \
	-e U7S_NODE_NAME=$(U7S_NODE_NAME) \
	-e U7S_NODE_SUBNET=$(U7S_NODE_SUBNET) \
	$(NODE_SERVICE_NAME)

.PHONY: help
help:
	@echo '# Bootstrap a cluster'
	@echo 'make up'
	@echo 'make kubeadm-init'
	@echo 'make install-flannel'
	@echo
	@echo '# Enable kubectl'
	@echo 'make kubeconfig'
	@echo 'export KUBECONFIG=$$(pwd)/kubeconfig'
	@echo 'kubectl get pods -A'
	@echo
	@echo '# Multi-host'
	@echo 'make join-command'
	@echo 'scp join-command another-host:~/usernetes'
	@echo 'ssh another-host make -C ~/usernetes up kubeadm-join'
	@echo
	@echo '# Debug'
	@echo 'make logs'
	@echo 'make shell'
	@echo 'make down-v'
	@echo 'kubectl taint nodes --all node-role.kubernetes.io/control-plane-'

.PHONY: up
up:
	$(COMPOSE) up --build -d

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: down-v
down-v:
	$(COMPOSE) down -v

.PHONY: shell
shell:
	$(NODE_SHELL) bash

.PHONY: logs
logs:
	$(NODE_SHELL) journalctl --follow --since="1 day ago"

.PHONY: kubeconfig
kubeconfig:
	$(COMPOSE) cp $(NODE_SERVICE_NAME):/etc/kubernetes/admin.conf ./kubeconfig
	@echo "# Run the following command by yourself:"
	@echo "export KUBECONFIG=$(shell pwd)/kubeconfig"

.PHONY: join-command
join-command:
	$(NODE_SHELL) kubeadm token create --print-join-command >join-command
	@echo "# Copy the 'join-command' file to another host, and run 'make kubeadm-join' on that host (not on this host)"

.PHONY: kubeadm-init
kubeadm-init:
	$(NODE_SHELL) sh -euc "envsubst </usernetes/kubeadm-config.yaml >/tmp/kubeadm-config.yaml"
	$(NODE_SHELL) kubeadm init --config /tmp/kubeadm-config.yaml

.PHONY: kubeadm-join
kubeadm-join:
	$(NODE_SHELL) $(shell cat join-command)

.PHONY: install-flannel
install-flannel:
	$(NODE_SHELL) kubectl apply -f /usernetes/manifests/kube-flannel.yml
