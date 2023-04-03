#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/kubelet.sh --container-runtime-endpoint unix://$XDG_RUNTIME_DIR/usernetes/containerd/containerd.sock $@
