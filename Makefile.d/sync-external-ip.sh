#!/bin/bash
set -eu -o pipefail

for node in $(kubectl get nodes -o name); do
	# Set ExternalIP
	host_ip="$(kubectl get "${node}" -o jsonpath='{.metadata.labels.usernetes/host-ip}')"
	kubectl patch "${node}" --type=merge --subresource status --patch \
		"\"status\": {\"addresses\": [{\"type\":\"ExternalIP\", \"address\": \"${host_ip}\"}]}"

	# Propagate ExternalIP to flannel
	# https://github.com/flannel-io/flannel/blob/v0.24.4/Documentation/kubernetes.md#annotations
	kubectl annotate "${node}" flannel.alpha.coreos.com/public-ip-overwrite=${host_ip}

	# Remove taints
	taints="$(kubectl get "${node}" -o jsonpath='{.spec.taints}')"
	if echo "${taints}" | grep -q node.cloudprovider.kubernetes.io/uninitialized; then
		kubectl taint nodes "${node}" node.cloudprovider.kubernetes.io/uninitialized-
	fi
done
