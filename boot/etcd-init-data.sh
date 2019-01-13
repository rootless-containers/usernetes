#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

: ${U7S_FLANNEL=}
if [[ $U7S_FLANNEL == 1 ]]; then
	config=$U7S_BASE_DIR/config/flannel/etcd/coreos.com_network_config
	set -x
	timeout 60 sh -c "until cat $config | etcdctl set /coreos.com/network/config; do sleep 1; done"
fi
