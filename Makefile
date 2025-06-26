# Run `make help` to show usage
.DEFAULT_GOAL := help

# Change ports for different kubernetes services
export PORT_ETCD ?= 2379
export PORT_KUBELET ?= 10250
export PORT_FLANNEL ?= 8472
export PORT_KUBE_APISERVER ?= 6443

# HOSTNAME is the name of the physical host
export HOSTNAME ?= $(shell hostname)
# HOST_IP is the IP address of the physical host. Accessible from other hosts.
export HOST_IP ?= $(shell ip --json route get 1 | jq -r .[0].prefsrc)
# NODE_NAME is the host name of the Kubernetes node running in Rootless Docker.
# Not accessible from other hosts.
export NODE_NAME ?= u7s-$(HOSTNAME)
# NODE_SUBNET is the subnet of the Kubernetes node running in Rootless Docker.
# Not accessible from other hosts.
export NODE_SUBNET ?= $(shell $(CURDIR)/Makefile.d/node-subnet.sh)
# NODE_IP is the IP address of the Kubernetes node running in Rootless Docker.
# Not accessible from other hosts.
export NODE_IP := $(subst .0/24,.100,$(NODE_SUBNET))

export CONTAINER_ENGINE ?= $(shell $(CURDIR)/Makefile.d/detect-container-engine.sh CONTAINER_ENGINE)

export CONTAINER_ENGINE_TYPE ?= $(shell $(CURDIR)/Makefile.d/detect-container-engine.sh CONTAINER_ENGINE_TYPE)

COMPOSE ?= $(shell $(CURDIR)/Makefile.d/detect-container-engine.sh COMPOSE)

NODE_SERVICE_NAME := node
NODE_SHELL := $(COMPOSE) exec \
	-e HOST_IP=$(HOST_IP) \
	-e NODE_NAME=$(NODE_NAME) \
	-e NODE_SUBNET=$(NODE_SUBNET) \
	-e NODE_IP=$(NODE_IP) \
	-e PORT_KUBE_APISERVER=$(PORT_KUBE_APISERVER) \
	-e PORT_FLANNEL=$(PORT_FLANNEL) \
	-e PORT_KUBELET=$(PORT_KUBELET) \
	-e PORT_ETCD=$(PORT_ETCD) \
	$(NODE_SERVICE_NAME)

ifeq ($(CONTAINER_ENGINE),nerdctl)
ifneq (,$(wildcard $(XDG_RUNTIME_DIR)/bypass4netnsd.sock))
	export BYPASS4NETNS := true
	export BYPASS4NETNS_IGNORE_SUBNETS := ["10.96.0.0/16", "10.244.0.0/16", "$(NODE_SUBNET)"]
endif
endif

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
	@echo 'make sync-external-ip'
	@echo
	@echo '# Debug'
	@echo 'make logs'
	@echo 'make shell'
	@echo 'make kubeadm-reset'
	@echo 'make down-v'
	@echo 'kubectl taint nodes --all node-role.kubernetes.io/control-plane-'

.PHONY: multi-node
multi-node:
	sed -i "s/default_network/$(HOSTNAME)/g" docker-compose.yaml

.PHONY: check-preflight
check-preflight:
	./Makefile.d/check-preflight.sh

.PHONY: render
render: check-preflight
	$(COMPOSE) config

.PHONY: up
up: check-preflight
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
	$(COMPOSE) exec -T $(NODE_SERVICE_NAME) sed -e "s/$(NODE_NAME)/127.0.0.1/g" /etc/kubernetes/admin.conf >kubeconfig
	@echo "# Run the following command by yourself:"
	@echo "export KUBECONFIG=$(shell pwd)/kubeconfig"
ifeq ($(shell command -v kubectl 2> /dev/null),)
	@echo "# To install kubectl, run the following command too:"
	@echo "make kubectl"
endif

.PHONY: kubectl
kubectl:
	$(COMPOSE) exec -T --workdir=/usr/bin $(NODE_SERVICE_NAME) tar c kubectl | tar xv
	@echo "# Run the following command by yourself:"
	@echo "export PATH=$(shell pwd):\$$PATH"
	@echo "source <(kubectl completion bash)"

.PHONY: join-command
join-command:
	echo "#!/bin/bash" >join-command
	echo "set -eux -o pipefail" >>join-command
	echo "echo \"$(HOST_IP)  $(NODE_NAME)\" >/etc/hosts.u7s" >>join-command
	echo "cat /etc/hosts.u7s >>/etc/hosts" >>join-command
	$(NODE_SHELL) kubeadm token create --print-join-command | tr -d '\r' >>join-command
	@echo "# Copy the 'join-command' file to another host, and run the following commands:"
	@echo "# On the other host (the new worker):"
	@echo "#   make kubeadm-join"
	@echo "# On this host (the control plane):"
	@echo "#   make sync-external-ip"

.PHONY: kubeadm-init
kubeadm-init:
	$(NODE_SHELL) sh -euc "envsubst </usernetes/kubeadm-config.yaml >/tmp/kubeadm-config.yaml"
	$(NODE_SHELL) kubeadm init --config /tmp/kubeadm-config.yaml --skip-token-print
	$(MAKE) sync-external-ip
	@echo "# Run 'make join-command' to print the join command"

.PHONY: sync-external-ip
sync-external-ip:
	$(NODE_SHELL) /usernetes/Makefile.d/sync-external-ip.sh

.PHONY: kubeadm-join
kubeadm-join:
	$(NODE_SHELL) /bin/bash /usernetes/join-command
	@echo "# Run 'make sync-external-ip' on the control plane"

.PHONY: kubeadm-reset
kubeadm-reset:
	$(NODE_SHELL) kubeadm reset --force

.PHONY: install-flannel
install-flannel:
	$(NODE_SHELL) /usernetes/Makefile.d/install-flannel.sh
