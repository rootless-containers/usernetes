#!/bin/bash
set -eu -o pipefail

for node in $(kubectl get nodes -o name); do
	# Set ExternalIP
	host_ip="$(kubectl get "${node}" -o jsonpath='{.metadata.labels.usernetes/host-ip}')"
	addresses="[{\"type\":\"ExternalIP\", \"address\": \"${host_ip}\"}]"

	# For Calico, set InternalIP too: Calico's IP autodetection is configured
	# to the node's InternalIP (Makefile.d/install-calico.sh), so that
	# calico-node picks the routable HOST_IP as the VXLAN tunnel endpoint
	# address on every boot, similarly to Flannel's `public-ip-overwrite`
	# annotation below. The CNI choice is recorded in /run/u7s-cni by
	# ../Dockerfile.d/u7s-entrypoint.sh (the CNI environment variable is not
	# reliable here; see the comment in the entrypoint).
	if [ "$(cat /run/u7s-cni 2>/dev/null)" = "calico" ]; then
		addresses="[{\"type\":\"ExternalIP\", \"address\": \"${host_ip}\"}, {\"type\":\"InternalIP\", \"address\": \"${host_ip}\"}]"
	fi
	kubectl patch "${node}" --type=merge --subresource status --patch \
		"\"status\": {\"addresses\": ${addresses}}"

	# Propagate ExternalIP to flannel
	# https://github.com/flannel-io/flannel/blob/v0.24.4/Documentation/kubernetes.md#annotations
	kubectl annotate "${node}" flannel.alpha.coreos.com/public-ip-overwrite=${host_ip}

	# Remove taints
	taints="$(kubectl get "${node}" -o jsonpath='{.spec.taints}')"
	if echo "${taints}" | grep -q node.cloudprovider.kubernetes.io/uninitialized; then
		kubectl taint nodes "${node}" node.cloudprovider.kubernetes.io/uninitialized-
	fi
done
