#!/bin/bash
set -eu -o pipefail
# clean up (workaround for crash of previously running instances)
(
	if ! [[ -w $XDG_RUNTIME_DIR ]]; then
		echo &>2 "XDG_RUNTIME_DIR needs to be set and writable"
		exit 1
	fi
	rootlesskit=$(realpath $(dirname $0))/bin/rootlesskit
	cd $XDG_RUNTIME_DIR
	$rootlesskit rm -rf docker docker.* containerd runc crio usernetes
)
exec $(dirname $0)/bin/task $@
