#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/nsenter.sh etcd --data-dir $XDG_DATA_HOME/usernetes/etcd $@
