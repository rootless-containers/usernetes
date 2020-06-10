#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

: ${U7S_FLANNEL=}
if [[ $U7S_FLANNEL == 1 ]]; then
	config=$U7S_BASE_DIR/config/flannel/etcd/coreos.com_network_config
	set -x
	timeout 60 sh -c "until cat $config | ETCDCTL_API=2 etcdctl --endpoints https://127.0.0.1:2379 --ca-file=$XDG_CONFIG_HOME/usernetes/master/ca.pem --cert-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes.pem --key-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes-key.pem set /coreos.com/network/config; do sleep 1; done"
fi
