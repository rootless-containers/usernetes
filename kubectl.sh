#!/bin/sh
set -e
PATH=$(dirname $0)/bin:$PATH
export PATH
nsenter -U -n -t $(cat /tmp/usernetes/rootlesskit/child_pid) hyperkube kubectl --kubeconfig=$(dirname $0)/localhost.kubeconfig $@
