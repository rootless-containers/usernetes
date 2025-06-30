#!/bin/bash
set -eux -o pipefail

if [ "$(id -u)" == "0" ]; then
	echo "Must not run as the root"
	exit 1
fi

: "${CONTAINER_ENGINE:=docker}"
: "${CONTAINER_ROOTFUL:=false}"
: "${XDG_CONFIG_HOME:=${HOME}/.config}"

setup_docker_rootless() {
	if [ "${CONTAINER_ROOTFUL}" = "true" ]; then
		return
	fi
	dockerd-rootless-setuptool.sh install || (journalctl --user --since "10 min ago"; exit 1)
}

case "${CONTAINER_ENGINE}" in
"docker")
	setup_docker_rootless
	;;
"docker-rootful")
	echo "Skipping rootless install of docker"
	CONTAINER_ENGINE="docker"
	;;
"nerdctl")
	containerd-rootless-setuptool.sh install
	containerd-rootless-setuptool.sh install-buildkit-containerd
	containerd-rootless-setuptool.sh install-bypass4netnsd
	;;
"podman")
	# pasta does not seem to work well
	# > 2024-12-02T17:15:40.070018488Z stderr F E1202 17:15:40.068621       1 main.go:228] Failed to create SubnetManager:
	# > error retrieving pod spec for 'kube-flannel/kube-flannel-ds-ms2d9': Get "https://10.96.0.1:443/api/v1/namespaces/kube-flannel/pods/kube-flannel-ds-ms2d9":
	# > dial tcp 10.96.0.1:443: i/o timeout
	mkdir -p "${XDG_CONFIG_HOME}/containers/containers.conf.d"
	cat <<EOF >"${XDG_CONFIG_HOME}/containers/containers.conf.d/slirp4netns.conf"
[network]
default_rootless_network_cmd="slirp4netns"
EOF
	systemctl --user enable --now podman-restart
	;;
*)
	# NOP
	;;
esac

${CONTAINER_ENGINE} info
