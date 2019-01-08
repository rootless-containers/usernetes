#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

exec $(dirname $0)/nsenter.sh hyperkube kubelet \
	--cert-dir $XDG_CONFIG_HOME/usernetes/pki \
	--root-dir $XDG_DATA_HOME/usernetes/kubelet \
	--log-dir $XDG_DATA_HOME/usernetes/kubelet-log \
	--volume-plugin-dir $XDG_DATA_HOME/usernetes/kubelet-plugins-exec \
	--kubeconfig $U7S_BASE_DIR/config/localhost.kubeconfig \
	--anonymous-auth=true \
	--authorization-mode=AlwaysAllow \
	--fail-swap-on=false \
	--feature-gates DevicePlugins=false \
	$@
