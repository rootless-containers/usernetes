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

case "$#" in
0)
	echo "CONTAINER_ENGINE=${CONTAINER_ENGINE}"
	echo "CONTAINER_ENGINE_TYPE=${CONTAINER_ENGINE_TYPE}"
	echo "COMPOSE=${COMPOSE}"
	;;
1)
	case "$1" in
	"CONTAINER_ENGINE" | "CONTAINER_ENGINE_TYPE" | "COMPOSE")
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
