#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/nsenter.sh kube-apiserver \
	--etcd-servers http://127.0.0.1:2379 \
    --service-cluster-ip-range=10.0.0.0/24 \
	--admission-control=AlwaysAdmit \
	--authorization-mode=AlwaysAllow \
	--anonymous-auth=true \
	--allow-privileged \
	$@
