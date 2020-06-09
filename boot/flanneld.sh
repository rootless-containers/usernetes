#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

: ${U7S_FLANNEL=}
if [[ $U7S_FLANNEL != 1 ]]; then
	log::error "U7S_FLANNEL needs to be 1"
	exit 1
fi

parent_ip=$(cat $XDG_RUNTIME_DIR/usernetes/parent_ip)

exec flanneld \
	--iface "tap0" \
	--ip-masq \
	--public-ip "$parent_ip" \
	--etcd-endpoints https://$(cat $XDG_CONFIG_HOME/usernetes/node/master):2379 \
	--etcd-cafile "$XDG_CONFIG_HOME/usernetes/master/ca.pem" \
	--etcd-certfile "$XDG_CONFIG_HOME/usernetes/master/kubernetes.pem" \
	--etcd-keyfile "$XDG_CONFIG_HOME/usernetes/master/kubernetes-key.pem" \
	$@

# FIXME: nodes should not require the master key.
# Currently nodes require the master key because flanneld and master
# share the same etcd cluster.
