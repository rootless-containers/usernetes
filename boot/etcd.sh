#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

# FIXME: no need to nsenter?
exec $(dirname $0)/nsenter.sh etcd \
	--data-dir $XDG_DATA_HOME/usernetes/etcd \
	--enable-v2=true \
	--name $(hostname -s) \
	--cert-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes.pem \
	--key-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes-key.pem \
	--peer-cert-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes.pem \
	--peer-key-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes-key.pem \
	--trusted-ca-file=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--peer-trusted-ca-file=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--peer-client-cert-auth \
	--client-cert-auth \
	--listen-client-urls https://0.0.0.0:2379 \
	--listen-peer-urls https://0.0.0.0:2380 \
	--advertise-client-urls https://127.0.0.1:2379 \
	--initial-advertise-peer-urls https://127.0.0.1:2380 \
	$@
