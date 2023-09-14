#!/bin/bash
set -eux -o pipefail

if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

if [ ! -e /etc/systemd/system/user@.service.d/delegate.conf ]; then
	mkdir -p /etc/systemd/system/user@.service.d
	cat <<EOF >/etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
	systemctl daemon-reload
fi

cat >/etc/modules-load.d/usernetes.conf <<EOF
br_netfilter
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

if command -v dnf >/dev/null 2>&1; then
	dnf install -y git shadow-utils make jq
else
	apt-get install -y git uidmap make jq
fi
