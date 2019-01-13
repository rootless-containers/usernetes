#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

mkdir -p $XDG_RUNTIME_DIR/usernetes
cat >$XDG_RUNTIME_DIR/usernetes/containerd.toml <<EOF
root = "$XDG_DATA_HOME/containerd"
state = "$XDG_RUNTIME_DIR/containerd"
[grpc]
  address = "$XDG_RUNTIME_DIR/containerd/containerd.sock"
[plugins]
  [plugins.linux]
    runtime_root = "$XDG_RUNTIME_DIR/containerd/runc"
  [plugins.cri]
    disable_cgroup = true
    disable_apparmor = true
    restrict_oom_score_adj = true
    [plugins.cri.containerd]
      snapshotter = "$(overlayfs::supported && echo overlayfs || echo native)"
    [plugins.cri.cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
EOF
exec containerd -c $XDG_RUNTIME_DIR/usernetes/containerd.toml $@
