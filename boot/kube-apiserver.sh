#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

exec $(dirname $0)/nsenter.sh hyperkube kube-apiserver \
	--etcd-servers http://127.0.0.1:2379 \
	--admission-control=AlwaysAdmit \
	--authorization-mode=AlwaysAllow \
	--anonymous-auth=true \
	$@
