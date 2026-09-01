#!/bin/bash
set -eux -o pipefail

if [ "$(id -u)" == "0" ]; then
	echo "Must not run as the root"
	exit 1
fi

: "${CONTAINER_ENGINE:=docker}"
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
case "${CONTAINER_ENGINE}" in
"docker")
	dockerd-rootless-setuptool.sh install || (journalctl --user --since "10 min ago"; exit 1)
	;;
"nerdctl")
	containerd-rootless-setuptool.sh install
	containerd-rootless-setuptool.sh install-buildkit-containerd
	containerd-rootless-setuptool.sh install-bypass4netnsd
	;;
"podman")
	mkdir -p "${XDG_CONFIG_HOME}/containers/containers.conf.d"
	PODMAN_VERSION_MAJOR="$(podman version --format '{{.Client.Version}}' | cut -d'.' -f1)"
	if [ "$PODMAN_VERSION_MAJOR" -ge 6 ]; then
		# By default, pasta copies the host's IP address into the rootless network
		# namespace, so the host's IP address does not hairpin back to the host.
		# This breaks accessing HOST_IP:6443 (kube-apiserver published on the host)
		# from inside the node, e.g., via the ClusterIP of the "kubernetes" service:
		# > Failed to create SubnetManager: error retrieving pod spec for 'kube-flannel/kube-flannel-ds-...':
		# > Get "https://10.96.0.1:443/...": dial tcp 10.96.0.1:443: i/o timeout
		# Specify a dedicated address (same as the slirp4netns default) with
		# `pasta_options` so that connections to HOST_IP are routed out to the host.
		cat <<EOF >"${XDG_CONFIG_HOME}/containers/containers.conf.d/pasta.conf"
[network]
default_rootless_network_cmd="pasta"
rootless_port_forwarder="pasta"
pasta_options=["-a", "10.0.2.100", "-n", "24", "-g", "10.0.2.2"]
EOF
	else
		# pasta does not seem to work well
		# > 2024-12-02T17:15:40.070018488Z stderr F E1202 17:15:40.068621       1 main.go:228] Failed to create SubnetManager:
		# > error retrieving pod spec for 'kube-flannel/kube-flannel-ds-ms2d9': Get "https://10.96.0.1:443/api/v1/namespaces/kube-flannel/pods/kube-flannel-ds-ms2d9":
		# > dial tcp 10.96.0.1:443: i/o timeout
		cat <<EOF >"${XDG_CONFIG_HOME}/containers/containers.conf.d/slirp4netns.conf"
[network]
default_rootless_network_cmd="slirp4netns"
EOF
	fi
	systemctl --user enable --now podman-restart
	;;
*)
	# NOP
	;;
esac

${CONTAINER_ENGINE} info
