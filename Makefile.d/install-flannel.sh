#!/bin/bash
set -eu -o pipefail

function INFO() {
	echo >&2 -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}
function WARNING() {
	echo >&2 -e "\e[101m\e[97m[WARNING]\e[49m\e[39m $@"
}

function ERROR() {
	echo >&2 -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@"
}

# See chart values, 0 indicates default for platform
# https://github.com/flannel-io/flannel/blob/v0.26.1/chart/kube-flannel/values.yaml
: "${U7S_PORT_FLANNEL:='0'}"

INFO "Flannel port: ${U7S_PORT_FLANNEL}"

# Check hard dependency commands
for cmd in helm kubectl; do
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		ERROR "Command \"${cmd}\" is not installed"
		exit 1
	fi
done

# Run this first in case a failure with kubectl
kubectl get pods -n kube-flannel
# Fall back to warning so a re-install does not fail
kubectl create namespace kube-flannel || WARNING "kube-flannel namespace might have been already created"
kubectl label --overwrite namespace kube-flannel pod-security.kubernetes.io/enforce=privileged || true
# If the command is issued again, this cleanup is needed
helm delete flannel --namespace kube-flannel || true
helm install flannel --namespace kube-flannel --set-json flannel.backendPort=${U7S_PORT_FLANNEL} /flannel
