#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/nsenter.sh dockerd \
	--experimental \
	--storage-driver $(overlayfs::supported && echo overlay2 || echo vfs) \
	--userland-proxy --userland-proxy-path $(which rootlesskit-docker-proxy) \
	$@
