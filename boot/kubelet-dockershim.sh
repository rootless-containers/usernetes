#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/kubelet.sh \
	--network-plugin=cni \
	--cni-conf-dir=/etc/cni/net.d \
	--cni-bin-dir=/opt/cni/bin \
	--docker-endpoint unix://$XDG_RUNTIME_DIR/docker.sock \
	$@
