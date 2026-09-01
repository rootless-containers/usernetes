#!/bin/bash
set -eux -o pipefail

# Append "KUBELET_EXTRA_ARGS=..." in /etc/default/kubelet
sed -e "s!\(^KUBELET_EXTRA_ARGS=.*\)!\\1 --cloud-provider=external --node-labels=usernetes/host-ip=${HOST_IP}!" </etc/default/kubelet | sponge /etc/default/kubelet

# Import control plane hosts from previous boot
[ -e /etc/hosts.u7s ] && cat /etc/hosts.u7s >>/etc/hosts

# Record the CNI choice (the CNI environment variable baked into the
# container by docker-compose.yaml, default: flannel) for the Makefile.d
# scripts executed via `compose exec`. The scripts cannot rely on the CNI
# environment variable: `podman-compose exec` overrides the environment of
# the container with the `environment` of docker-compose.yaml re-interpolated
# in the environment of the `podman-compose exec` caller.
echo "${CNI:-flannel}" >/run/u7s-cni

# Calico-specific hacks. Only applied when the CNI is explicitly configured
# to Calico (CNI=calico), so as to keep the Flannel (default) configuration
# intact. See Makefile.d/install-calico.sh for the rest of the configuration.
if [ "${CNI:-}" = "calico" ]; then
	# Assign HOST_IP to eth0 as an additional address, so that Calico's felix
	# can find the "parent interface" of the vxlan.calico device: felix
	# requires the IPv4 address of the Calico Node resource (HOST_IP, i.e.,
	# the node's InternalIP set by Makefile.d/sync-external-ip.sh) to be
	# assigned to a local interface. The prefix length is /32, so as not to
	# alter the routing table.
	if ! ip -4 -o addr show dev eth0 | grep -qF "inet ${HOST_IP}/"; then
		ip addr add "${HOST_IP}/32" dev eth0 || echo >&2 "Failed to assign ${HOST_IP} to eth0"
	fi

	# Stateless NAT for Calico VXLAN packets. Calico's felix marks the VXLAN
	# packets as NOTRACK, so the regular (conntrack-based) NAT cannot be
	# applied to them:
	# - Outbound: the outer source address is HOST_IP (the address of the
	#   vxlan.calico device, assigned to eth0 above), which is not covered by
	#   the MASQUERADE rule of the container engine's bridge network, so the
	#   packets would be discarded by the rootless network stack (slirp4netns,
	#   pasta, gvisor-tap-vsock, ...). Rewrite the source address to NODE_IP
	#   so that the packets are masqueraded as usual, like Flannel's VXLAN
	#   packets.
	# - Inbound: the port forwarder of the rootless network stack rewrites the
	#   source address to an address of the container engine's bridge network
	#   (e.g., 10.100.X.1), which would be discarded by felix's "Drop IPv4
	#   VXLAN packets from non-allowed hosts" rule. Rewrite the source address
	#   to the sentinel address 169.254.7.115 ("7s"), which is allowed via the
	#   `externalNodesList` property of the FelixConfiguration
	#   (see Makefile.d/install-calico.sh).
	nft -f - <<EOF || echo >&2 "Failed to set up stateless NAT for Calico VXLAN"
table ip u7s-calico-vxlan {
  chain postrouting {
    type filter hook postrouting priority 150; policy accept;
    oifname "eth0" ip saddr ${HOST_IP} udp dport ${PORT_CALICO} ip saddr set ${NODE_IP}
  }
  chain prerouting {
    type filter hook prerouting priority raw; policy accept;
    iifname "eth0" udp dport ${PORT_CALICO} ip saddr set 169.254.7.115
  }
}
EOF
fi

# Set sysctls in the container's network namespace (best-effort).
# In the Docker Compose mode, these are set via docker-compose.yaml and the
# host configuration. When running as a Kubernetes pod (../kubernetes), they
# have to be set here, as "unsafe" sysctls cannot be set via the pod spec
# without reconfiguring the kubelet of the outer cluster.
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
	echo 1 >/proc/sys/net/ipv4/ip_forward || echo >&2 "Failed to enable net.ipv4.ip_forward"
fi
# rp_filter must be 0 (disabled) or 2 (loose), must not be 1 (strict)
for f in /proc/sys/net/ipv4/conf/default/rp_filter /proc/sys/net/ipv4/conf/all/rp_filter; do
	if [ "$(cat "$f")" == "1" ]; then
		echo 2 >"$f" || echo >&2 "Failed to set ${f} to 2 (loose)"
	fi
done

# Propagate FLANNEL_IGNORE_IP_CHECKSUM to the udev rule, as udev RUN programs
# cannot see the environment variables of the container.
case "${FLANNEL_IGNORE_IP_CHECKSUM:-}" in
"1" | "true")
	touch /run/u7s-flannel-ignore-ip-checksum
	;;
esac

# Support for Rootful
if [ "$(readlink /proc/self/ns/user)" = "user:[4026531837]" ]; then
	# Disable checksum offloading on eth0, apparently needed for running Usernetes
	# under Rootful Docker. Applied here rather than via a udev rule, as eth0 is
	# created before udevd starts in the container.
	# https://github.com/rootless-containers/usernetes/pull/366#issuecomment-2678413236
	if [ -e /sys/class/net/eth0 ]; then
		ethtool -K eth0 tx-checksum-ip-generic off || echo >&2 "Failed to disable tx-checksum-ip-generic on eth0"
	fi
fi

exec "$@"
