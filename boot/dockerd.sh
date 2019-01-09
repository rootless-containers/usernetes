#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

exec $(dirname $0)/nsenter.sh dockerd \
	--experimental \
	--storage-driver $(overlayfs::supported && echo overlay2 || echo vfs) \
	$@
