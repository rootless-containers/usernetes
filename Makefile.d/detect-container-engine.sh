#!/bin/bash
set -eu -o pipefail
: "${CONTAINER_ENGINE:=}"
: "${COMPOSE:=}"

if [ -z "${CONTAINER_ENGINE}" ]; then
	if command -v dockerd-rootless.sh >/dev/null 2>&1; then
		CONTAINER_ENGINE=docker
	elif command -v containerd-rootless.sh >/dev/null 2>&1; then
		CONTAINER_ENGINE=nerdctl
	elif command -v podman >/dev/null 2>&1; then
		CONTAINER_ENGINE=podman
	else
		echo >&2 "$0: no container engine was detected"
		exit 1
	fi
fi

CONTAINER_ENGINE_TYPE=docker
if [[ "${CONTAINER_ENGINE}" = *"podman"* ]]; then
	CONTAINER_ENGINE_TYPE=podman
elif [[ "${CONTAINER_ENGINE}" = *"nerdctl"* ]]; then
	CONTAINER_ENGINE_TYPE=nerdctl
fi

if [ -z "${COMPOSE}" ]; then
	COMPOSE="${CONTAINER_ENGINE} compose"
	if [ "${CONTAINER_ENGINE_TYPE}" = "podman" ]; then
		COMPOSE=podman-compose
	fi
fi

# SLIRP4NETNS is set to 1 when the container engine provides the network with slirp4netns.
# slirp4netns silently drops VXLAN packets with an unfilled UDP checksum,
# so the flannel.1 udev rule (Dockerfile.d/etc_udev_rules.d_90-flannel.rules)
# has to disable the checksum offloading.
# The variable can also be set manually to override the detection.
: "${SLIRP4NETNS:=}"
if [ -z "${SLIRP4NETNS}" ]; then
	case "${CONTAINER_ENGINE_TYPE}" in
	"podman")
		if [ "$(${CONTAINER_ENGINE} info --format '{{.Host.Security.Rootless}}/{{.Host.RootlessNetworkCmd}}' 2>/dev/null)" = "true/slirp4netns" ]; then
			SLIRP4NETNS=1
		fi
		;;
	"docker" | "nerdctl")
		# The RootlessKit network driver is exposed as the "rootlesskit" server
		# component (absent in the rootful mode).
		if [ "$(${CONTAINER_ENGINE} version --format '{{range .Server.Components}}{{if eq .Name "rootlesskit"}}{{.Details.NetworkDriver}}{{end}}{{end}}' 2>/dev/null)" = "slirp4netns" ]; then
			SLIRP4NETNS=1
		fi
		;;
	esac
fi

case "$#" in
0)
	echo "CONTAINER_ENGINE=${CONTAINER_ENGINE}"
	echo "CONTAINER_ENGINE_TYPE=${CONTAINER_ENGINE_TYPE}"
	echo "COMPOSE=${COMPOSE}"
	echo "SLIRP4NETNS=${SLIRP4NETNS}"
	;;
1)
	case "$1" in
	"CONTAINER_ENGINE" | "CONTAINER_ENGINE_TYPE" | "COMPOSE" | "SLIRP4NETNS")
		echo "${!1}"
		;;
	*)
		echo >&2 "$0: unknown argument: $1"
		exit 1
		;;
	esac
	;;
*)
	echo >&2 "$0: too many arguments"
	exit 1
	;;
esac
