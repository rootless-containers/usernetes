#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

exec $(dirname $0)/kubelet.sh --container-runtime remote --container-runtime-endpoint unix:///run/crio/crio.sock $@
