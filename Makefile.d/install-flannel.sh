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

# Extra values for the Flannel chart (YAML)
flannel_values() {
	if [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
		return
	fi
	# Linux kernel 7.4 no longer supports br_netfilter in user namespaces,
	# and the module is slated for removal in 2027:
	# > br_netfilter no longer supported in user namespaces
	# https://patchwork.ozlabs.org/project/netfilter-devel/patch/20260831151107.25269-1-fw@strlen.de/
	#
	# Without br_netfilter:
	# - flanneld (iptables mode) refuses to start:
	#   > Failed to check br_netfilter: stat /proc/sys/net/bridge/bridge-nf-call-iptables: no such file or directory
	#   The check is skipped in the nftables mode.
	# - The packets bridged across the pods on the same node bypass the NAT
	#   rules of kube-proxy, so a pod cannot connect to a Service backed by
	#   a pod on the same node. Use the "ptp" plugin instead of the "bridge"
	#   plugin, so that all the packets are routed (not bridged) via the node.
	#
	# The condition is evaluated on the control plane node, assuming that
	# all the nodes are running similar kernels.
	echo >&2 "br_netfilter is not available: configuring Flannel to use nftables and the ptp plugin"
	cat <<EOF
flannel:
  enableNFTables: true
  # "ipam" has to be specified here, not in "delegate".
  # The route to the pod network is automatically added by the flannel plugin.
  cniConf: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "ipam": {
            "routes": [{"dst": "0.0.0.0/0"}]
          },
          "delegate": {
            "type": "ptp"
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
EOF
}

if ! helm -n kube-flannel list -q | grep flannel; then
	kubectl create namespace kube-flannel
	kubectl label --overwrite namespace kube-flannel pod-security.kubernetes.io/enforce=privileged
	# The values are passed via the stdin, so as to avoid creating a temporary file
	flannel_values |
		helm install flannel --namespace kube-flannel --set-json flannel.backendPort=${PORT_FLANNEL} --set podCidr="${POD_SUBNET}" -f - /flannel
fi
