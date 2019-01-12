#!/bin/bash
export U7S_BASE_DIR=$(dirname $0)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

exec hyperkube kubectl --kubeconfig=$U7S_KUBECONFIG $@
