#!/bin/bash
source $(dirname $0)/../common/common.inc.sh
nsenter::main $0 $@

if [[ $# -eq 0 ]]; then
	exec $SHELL $@
else
	exec $@
fi
