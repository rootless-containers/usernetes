#!/bin/bash
set -eu -o pipefail

# The CNI choice is recorded in /run/u7s-cni by
# ../Dockerfile.d/u7s-entrypoint.sh (the CNI environment variable is not
# reliable here; see the comment in the entrypoint). CNI=calico enables the
# Calico-specific hacks of the entrypoint.
if [ "$(cat /run/u7s-cni 2>/dev/null)" != "calico" ]; then
	echo >&2 "CNI has to be explicitly set to \"calico\" on creating the node: \`CNI=calico make up\`"
	exit 1
fi

# Default: 4789 (the IANA-assigned VXLAN port).
# Set via the Makefile (../Makefile).
: "${PORT_CALICO:?}"
# Must correspond to the podSubnet of kubeadm-config.yaml.
# Set via the Makefile (../Makefile).
: "${POD_SUBNET:?}"

# Install the Calico CRDs, shipped in a chart separate from tigera-operator.
# `helm template | kubectl apply --server-side` is the installation method
# documented in the tigera-operator chart, as some of the CRDs exceed the
# size limit of the client-side apply.
helm template calico-crds /calico/crd.projectcalico.org.v1 | kubectl apply --server-side -f -
kubectl wait --timeout=1m --for=condition=established \
	crd/installations.operator.tigera.io crd/felixconfigurations.crd.projectcalico.org

# Install tigera-operator with the values rendered from
# ../calico-helm-values.yaml .
#
# Not `helm upgrade --install`, as the upgrade conflicts with the fields of
# the Installation object that tigera-operator takes the ownership of
# (e.g., .spec.calicoNetwork.ipPools).
if ! helm --namespace tigera-operator list -q | grep calico; then
	envsubst '$POD_SUBNET $PORT_CALICO' </usernetes/calico-helm-values.yaml |
		helm install calico /calico/tigera-operator \
			--namespace tigera-operator --create-namespace -f -
fi
