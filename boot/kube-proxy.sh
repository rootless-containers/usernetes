#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

exec $(dirname $0)/nsenter.sh hyperkube kube-proxy --kubeconfig $U7S_BASE_DIR/config/localhost.kubeconfig --proxy-mode=userspace $@
