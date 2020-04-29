#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/nsenter.sh kubelet \
	--cert-dir $XDG_CONFIG_HOME/usernetes/pki \
	--root-dir $XDG_DATA_HOME/usernetes/kubelet \
	--log-dir $XDG_DATA_HOME/usernetes/kubelet-log \
	--volume-plugin-dir $XDG_DATA_HOME/usernetes/kubelet-plugins-exec \
	--kubeconfig $U7S_KUBECONFIG \
	--anonymous-auth=true \
	--authorization-mode=AlwaysAllow \
	--fail-swap-on=false \
	--feature-gates DevicePlugins=false,SupportNoneCgroupDriver=true,LocalStorageCapacityIsolation=false \
	--eviction-hard "nodefs.available<3%" \
	--cgroup-driver=none --cgroups-per-qos=false --enforce-node-allocatable="" \
	$@

# Notes
# --evictrion-hard: Relax disk pressure taint for CI
# LocalStorageCapacityIsolation=false: workaround for "Failed to start ContainerManager failed to get rootfs info" error on Fedora 32: https://github.com/rootless-containers/usernetes/pull/157#issuecomment-621008594
