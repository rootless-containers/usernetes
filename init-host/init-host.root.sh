#!/bin/bash
set -eux -o pipefail

if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

: "${CONTAINER_ENGINE:=docker}"
script_dir="$(dirname "$0")"

if [ ! -e /etc/systemd/system/user@.service.d/delegate.conf ]; then
	mkdir -p /etc/systemd/system/user@.service.d
	cat <<EOF >/etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
	systemctl daemon-reload
fi

cat >/etc/modules-load.d/usernetes.conf <<EOF
tun
tap
bridge
br_netfilter
veth
ip_tables
ip6_tables
iptable_nat
ip6table_nat
iptable_filter
ip6table_filter
nf_tables
x_tables
xt_MASQUERADE
xt_addrtype
xt_comment
xt_conntrack
xt_mark
xt_multiport
xt_nat
xt_tcpudp
vxlan
EOF
systemctl restart systemd-modules-load.service

cat >/etc/sysctl.d/99-usernetes.conf <<EOF
# For VXLAN, net.ipv4.conf.default.rp_filter must not be 1 (strict) in the daemon's netns.
# It may still remain 1 in the host netns, but there is no robust and simple way to
# configure sysctl for the daemon's netns. So we are configuring it globally here.
net.ipv4.conf.default.rp_filter = 2
EOF
sysctl --system

if command -v dnf >/dev/null 2>&1; then
	dnf install -y git shadow-utils make jq
	# podman-compose requires EPEL
	if grep -q centos /etc/os-release; then
		# Works with Rocky and Alma too
		dnf -y install epel-release
	fi
else
	apt-get update
	apt-get install -y git uidmap make jq
fi

case "${CONTAINER_ENGINE}" in
"docker")
	if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
		if grep -q centos /etc/os-release; then
			# Works with Rocky and Alma too
			dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
			dnf -y install docker-ce
		else
			curl https://get.docker.com | sh
		fi
	fi
	systemctl disable --now docker
	;;
"podman")
	if ! command -v podman-compose >/dev/null 2>&1; then
		"${script_dir}"/init-host.root.d/install-podman.sh
	fi
	;;
"nerdctl")
	if ! command -v nerdctl >/dev/null 2>&1; then
		"${script_dir}"/init-host.root.d/install-nerdctl.sh
	fi
	;;
*)
	echo >&2 "Unsupported container engine: ${CONTAINER_ENGINE}"
	exit 1
	;;
esac
