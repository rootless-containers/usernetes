#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

exec $(dirname $0)/kubelet.sh --docker-endpoint unix://$XDG_RUNTIME_DIR/docker.sock $@
