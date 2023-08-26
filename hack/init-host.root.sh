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

if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
	curl https://get.docker.com | sh
fi
systemctl disable --now docker

apt-get install -y uidmap make jq
