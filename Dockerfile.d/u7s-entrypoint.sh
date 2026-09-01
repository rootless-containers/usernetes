#!/bin/bash
set -eux -o pipefail

# Append "KUBELET_EXTRA_ARGS=..." in /etc/default/kubelet
sed -e "s!\(^KUBELET_EXTRA_ARGS=.*\)!\\1 --cloud-provider=external --node-labels=usernetes/host-ip=${HOST_IP}!" </etc/default/kubelet | sponge /etc/default/kubelet

# Import control plane hosts from previous boot
[ -e /etc/hosts.u7s ] && cat /etc/hosts.u7s >>/etc/hosts

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

# Propagate SLIRP4NETNS to the udev rule, as udev RUN programs cannot see the
# environment variables of the container.
case "${SLIRP4NETNS:-}" in
"1" | "true")
	touch /run/u7s-slirp4netns
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
