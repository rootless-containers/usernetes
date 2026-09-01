#!/bin/bash
set -eu -o pipefail

# The CNI choice is recorded in /run/u7s-cni by
# ../Dockerfile.d/u7s-entrypoint.sh (the CNI environment variable is not
# reliable here; see the comment in the entrypoint).
if [ "$(cat /run/u7s-cni 2>/dev/null || echo flannel)" != "flannel" ]; then
	echo >&2 "The node was created with CNI=calico: run \`CNI=calico make install-cni\`, or recreate the node with \`make up\` to use Flannel"
	exit 1
fi

# See chart values, 0 indicates default for platform
# https://github.com/flannel-io/flannel/blob/v0.26.1/chart/kube-flannel/values.yaml
: "${PORT_FLANNEL:='0'}"
# Must correspond to the podSubnet of kubeadm-config.yaml.
# Set via the Makefiles (../Makefile and ../kubernetes/Makefile).
: "${POD_SUBNET:?}"

if ! helm -n kube-flannel list -q | grep flannel; then
	kubectl create namespace kube-flannel
	kubectl label --overwrite namespace kube-flannel pod-security.kubernetes.io/enforce=privileged
	helm install flannel --namespace kube-flannel --set-json flannel.backendPort=${PORT_FLANNEL} --set podCidr="${POD_SUBNET}" /flannel
fi
