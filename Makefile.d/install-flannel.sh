#!/bin/bash
set -eu -o pipefail

# See chart values, 0 indicates default for platform
# https://github.com/flannel-io/flannel/blob/v0.26.1/chart/kube-flannel/values.yaml
: "${PORT_FLANNEL:='0'}"

if ! helm -n kube-flannel list -q | grep flannel; then
	kubectl create namespace kube-flannel
	kubectl label --overwrite namespace kube-flannel pod-security.kubernetes.io/enforce=privileged
	helm install flannel --namespace kube-flannel --set-json flannel.backendPort=${PORT_FLANNEL} /flannel
fi
