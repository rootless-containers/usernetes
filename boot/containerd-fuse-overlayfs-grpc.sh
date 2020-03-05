#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

mkdir -p $XDG_RUNTIME_DIR/usernetes/containerd $XDG_DATA_HOME/usernetes/containerd

exec containerd-fuse-overlayfs-grpc \
	$@ \
	$XDG_RUNTIME_DIR/usernetes/containerd/fuse-overlayfs.sock \
	$XDG_DATA_HOME/usernetes/containerd/io.containerd.snapshotter.v1.fuse-overlayfs
