#!/bin/bash
set -eu -o pipefail
PATH=$(dirname $0)/bin:$PATH
export PATH
exec nsenter -U --preserve-credential -n -t $(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid) hyperkube kubectl --kubeconfig=$(dirname $0)/config/localhost.kubeconfig $@
