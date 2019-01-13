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

# FIXME: etcd URL is hard-coded for docker-compose
exec flanneld --ip-masq --etcd-endpoints http://master:2379 --public-ip $parent_ip $@
