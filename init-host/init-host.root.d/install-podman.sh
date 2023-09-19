#!/bin/bash
# This script installs the latest release of Podman.
# Repository information is from https://podman.io/docs/installation#linux-distributions
set -eux -o pipefail
if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

if command -v dnf >/dev/null 2>&1; then
	dnf install -y podman podman-compose
else
	mkdir -p /etc/apt/keyrings
	curl -fsSL "https://download.opensuse.org/repositories/devel:kubic:libcontainers:unstable/xUbuntu_$(lsb_release -rs)/Release.key" |
		gpg --dearmor |
		tee /etc/apt/keyrings/devel_kubic_libcontainers_unstable.gpg >/dev/null
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/devel_kubic_libcontainers_unstable.gpg]\
        https://download.opensuse.org/repositories/devel:kubic:libcontainers:unstable/xUbuntu_$(lsb_release -rs)/ /" |
		tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list >/dev/null
	apt-get update -qq
	apt-get -qq -y install podman
	# No dpkg for podman-compose ?
	pip3 install podman-compose
fi
