#!/bin/bash
# This script installs Podman.
set -eux -o pipefail
if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

if command -v dnf >/dev/null 2>&1; then
	dnf install -y podman podman-compose
else
	apt-get update -qq
	apt-get -qq -y install podman podman-compose
fi
