# Run `make help` to show usage
.DEFAULT_GOAL := help

# U7S_IMAGE is the image of the node pods, built from the top-level
# Dockerfile. The default image is pushed to GHCR by the CI
# (../.github/workflows/image.yaml) on every push to the master branch.
export U7S_IMAGE ?= ghcr.io/rootless-containers/usernetes:master

# U7S_RUNTIME_CLASS_NAME is the RuntimeClass of the node pods, expected to be
# backed by a runtime handler with `cgroup_writable = true` (containerd).
# Empty (default) means the default runtime handler of the outer cluster,
# which then has to mount /sys/fs/cgroup of the node pods read-write by
# itself. See ./README.md.
export U7S_RUNTIME_CLASS_NAME ?=

# U7S_NAMESPACE is the namespace in the outer Kubernetes cluster.
export U7S_NAMESPACE ?= usernetes

# U7S_WORKER_REPLICAS is the number of the worker node pods.
export U7S_WORKER_REPLICAS ?= 1

# U7S_POD_SUBNET and U7S_SERVICE_SUBNET are the subnets of the inner cluster.
# They must not overlap with the subnets used by the outer cluster (pods,
# services, nodes), so the defaults here differ from the Docker Compose mode
# (10.244.0.0/16 and 10.96.0.0/16; see ../Makefile), which would clash with
# typical outer clusters (e.g., kubeadm with flannel, or kind).
export U7S_POD_SUBNET ?= 10.200.0.0/16
export U7S_SERVICE_SUBNET ?= 10.201.0.0/16

# CNI is the CNI of the inner cluster. Unlike in the Docker Compose mode
# (../Makefile), only Flannel is supported: calico-node requires
# `privileged: true` with `hostNetwork`, which cannot be fulfilled inside a
# userns node pod (see the comment on `patch-kube-proxy` below), and unlike
# kube-proxy, the DaemonSet cannot be patched to drop the privileges, as it
# is reconciled by tigera-operator.
CNI ?= flannel

# U7S_KUBE_APISERVER_LOCAL_PORT is the local port used by `make port-forward`
# (and written into the kubeconfig by `make kubeconfig`) for reaching the API
# server of the inner cluster. Set it to a free port when 127.0.0.1:6443 is
# already taken, e.g., by the API server of the outer cluster (as with k3s).
export U7S_KUBE_APISERVER_LOCAL_PORT ?= 6443

KUBECTL ?= kubectl

CONTROL_PLANE_POD := u7s-control-plane-0
# NODE_NAME of the control plane. Must correspond to the value in ./usernetes.yaml .
CONTROL_PLANE_NODE_NAME := $(CONTROL_PLANE_POD).u7s
NODE_EXEC := $(KUBECTL) exec --namespace=$(U7S_NAMESPACE)

.PHONY: help
help:
	@echo '# Bootstrap a cluster (inside an existing Kubernetes cluster)'
	@echo 'export U7S_IMAGE=<registry>/usernetes:latest'
	@echo 'make up'
	@echo 'make kubeadm-init'
	@echo 'make install-cni'
	@echo 'make kubeadm-join'
	@echo
	@echo '# Enable kubectl'
	@echo 'make kubeconfig'
	@echo 'make port-forward   # Run in a separate terminal'
	@echo 'export KUBECONFIG=$$(pwd)/kubeconfig'
	@echo 'kubectl get pods -A'
	@echo
	@echo '# Debug'
	@echo 'make logs'
	@echo 'make shell'
	@echo 'make down'

.PHONY: render
render:
	@command -v envsubst >/dev/null 2>&1 || { echo >&2 'Command "envsubst" (GNU gettext) is not installed'; exit 1; }
	@envsubst '$$U7S_NAMESPACE $$U7S_IMAGE $$U7S_WORKER_REPLICAS $$U7S_POD_SUBNET $$U7S_SERVICE_SUBNET $$U7S_RUNTIME_CLASS_NAME' <usernetes.yaml

.PHONY: up
up:
	$(MAKE) --silent render | $(KUBECTL) apply -f -
	for f in u7s-control-plane u7s-worker; do \
		$(KUBECTL) --namespace=$(U7S_NAMESPACE) rollout status --timeout=5m statefulset/$$f; \
	done

.PHONY: down
down:
	$(MAKE) --silent render | $(KUBECTL) delete --ignore-not-found -f -

.PHONY: shell
shell:
	$(NODE_EXEC) -it $(CONTROL_PLANE_POD) -- bash

.PHONY: logs
logs:
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- journalctl --follow --since="1 day ago"

.PHONY: kubeconfig
kubeconfig:
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- sed -e "s/$(CONTROL_PLANE_NODE_NAME):6443/127.0.0.1:$(U7S_KUBE_APISERVER_LOCAL_PORT)/g" /etc/kubernetes/admin.conf >kubeconfig
	@echo "# Run the following commands by yourself:"
	@echo "make port-forward   # Run in a separate terminal"
	@echo "export KUBECONFIG=$(shell pwd)/kubeconfig"

.PHONY: port-forward
port-forward:
	$(KUBECTL) --namespace=$(U7S_NAMESPACE) port-forward pod/$(CONTROL_PLANE_POD) $(U7S_KUBE_APISERVER_LOCAL_PORT):6443

.PHONY: kubeadm-init
kubeadm-init:
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- sh -euc "envsubst </usernetes/kubeadm-config.yaml >/tmp/kubeadm-config.yaml"
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- kubeadm init --config /tmp/kubeadm-config.yaml --skip-token-print
	$(MAKE) patch-kube-proxy
	$(MAKE) sync-external-ip
	@echo "# Run 'make kubeadm-join' to join the worker pods"

# The kube-proxy DaemonSet created by kubeadm runs with privileged: true,
# which cannot be fulfilled inside a userns node pod: the sandbox of a
# privileged pod with hostNetwork gets a fresh read-write sysfs mount, and
# mounting sysfs requires the network namespace to be owned by the user
# namespace, while the network namespace of the node pod is created by the
# CRI of the outer cluster (i.e., owned by the initial user namespace).
# So, drop privileged and grant just the capabilities needed for iptables.
# The conntrack sysctls are already skipped via ../kubeadm-config.yaml .
.PHONY: patch-kube-proxy
patch-kube-proxy:
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- kubectl --namespace=kube-system patch daemonset kube-proxy --patch '{"spec":{"template":{"spec":{"containers":[{"name":"kube-proxy","securityContext":{"privileged":false,"capabilities":{"add":["NET_ADMIN","NET_RAW"]}}}]}}}}'

.PHONY: sync-external-ip
sync-external-ip:
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- /usernetes/Makefile.d/sync-external-ip.sh

.PHONY: kubeadm-join
kubeadm-join:
	@set -eu; \
	join_command="$$($(NODE_EXEC) $(CONTROL_PLANE_POD) -- kubeadm token create --print-join-command | tr -d '\r')"; \
	for pod in $$($(KUBECTL) get pods --namespace=$(U7S_NAMESPACE) -l app.kubernetes.io/component=worker -o name); do \
		echo "Joining $${pod}"; \
		$(NODE_EXEC) "$${pod}" -- sh -euc "if [ -e /etc/kubernetes/kubelet.conf ]; then echo 'Already joined, skipping'; else $${join_command}; fi"; \
	done
	$(MAKE) sync-external-ip

.PHONY: kubeadm-reset
kubeadm-reset:
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- kubeadm reset --force

# Installs $(CNI) ("flannel" by default). Only Flannel is supported in this
# mode; see the comment on the CNI variable above.
.PHONY: install-cni
install-cni:
ifneq ($(CNI),flannel)
	$(error Only Flannel is supported in the Kubernetes-in-Kubernetes mode; see ./README.md)
endif
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- /usernetes/Makefile.d/install-$(CNI).sh

.PHONY: install-flannel
install-flannel:
	@echo >&2 'DEPRECATED: Use `make install-cni` instead'
	$(NODE_EXEC) $(CONTROL_PLANE_POD) -- /usernetes/Makefile.d/install-flannel.sh
