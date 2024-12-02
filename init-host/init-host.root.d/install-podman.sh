#!/bin/bash
# This script installs Podman.
set -eux -o pipefail
if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

# Needs slirp4netns, not pasta:
#
# > 2024-12-02T17:15:40.070018488Z stderr F E1202 17:15:40.068621       1 main.go:228] Failed to create SubnetManager:
# > error retrieving pod spec for 'kube-flannel/kube-flannel-ds-ms2d9': Get "https://10.96.0.1:443/api/v1/namespaces/kube-flannel/pods/kube-flannel-ds-ms2d9":
# > dial tcp 10.96.0.1:443: i/o timeout

if command -v dnf >/dev/null 2>&1; then
	dnf install -y podman podman-compose slirp4netns
else
	apt-get update -qq
	apt-get -qq -y install podman podman-compose slirp4netns
fi
