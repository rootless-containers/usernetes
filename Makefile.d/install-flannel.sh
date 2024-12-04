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
: "${U7S_PORT_ETCD:='2379'}"

INFO "Flannel port: ${U7S_PORT_FLANNEL}"
INFO "ETCD port: ${U7S_PORT_ETCD}"

# Check hard dependency commands
for cmd in helm kubectl git; do
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		ERROR "Command \"${cmd}\" is not installed"
		exit 1
	fi
done

# We need to customize the values.yaml to expose the backendPort and args
flannel_root=$(mktemp -d -u -t flannel-XXXXXXX)
git clone --quiet --depth 1 --branch v0.26.1 https://github.com/flannel-io/flannel $flannel_root
cd $flannel_root/chart

# Write a new values.yaml that exposes what we need
cat <<EOF > ./new-values.yaml
---
global:
  imagePullSecrets:
# - name: "a-secret-name"

# The IPv4 cidr pool to create on startup if none exists. Pod IPs will be
# chosen from this range.
podCidr: "10.244.0.0/16"
podCidrv6: ""
flannel:
  # kube-flannel image
  image:
    repository: docker.io/flannel/flannel
    tag: v0.26.1
  image_cni:
    repository: docker.io/flannel/flannel-cni-plugin
    tag: v1.5.1-flannel2
  # flannel command arguments
  enableNFTables: false
  args:
  - "--ip-masq"
  - "--kube-subnet-mgr"
  # Disabled, but left here for awareness that it can be set.
  # It is not used as kube-subnet-mgr is enabled:
  # https://github.com/flannel-io/flannel/blob/v0.26.1/Documentation/configuration.md
  # - "--etcd-endpoints=\"http://127.0.0.1:4001,https://${U7S_HOST_IP}:${U7S_PORT_ETCD},http://127.0.0.1:${U7S_PORT_ETCD}\""
  # Backend for kube-flannel. Backend should not be changed
  # at runtime. (vxlan, host-gw, wireguard, udp)
  # Documentation at https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md
  backend: "vxlan"
  # Port used by the backend 0 means default value (VXLAN: 8472, Wireguard: 51821, UDP: 8285)
  backendPort: ${U7S_PORT_FLANNEL}
  tolerations:
  - effect: NoExecute
    operator: Exists
  - effect: NoSchedule
    operator: Exists

netpol:
  enabled: false
EOF

mv ./new-values.yaml ./kube-flannel/values.yaml

# Run this first in case a failure with kubectl
kubectl get pods -n kube-flannel
# Fall back to warning so a re-install does not fail
kubectl create namespace kube-flannel || WARNING "kube-flannel namespace might have been already created"
kubectl label --overwrite namespace kube-flannel pod-security.kubernetes.io/enforce=privileged || true
# If the command is issued again, this cleanup is needed
helm delete flannel --namespace kube-flannel kube-flannel || true
# We could also do --set flannel.backendPort=<value> but it's the same to set as the default
helm install flannel --namespace kube-flannel kube-flannel
cd -
rm -rf $flannel_root
