#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/nsenter.sh kube-scheduler \
	--kubeconfig=$XDG_CONFIG_HOME/usernetes/master/kube-scheduler.kubeconfig \
	$@
