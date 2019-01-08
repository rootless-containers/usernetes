#!/bin/bash
source $(dirname $0)/../common/common.inc.sh

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
    # If you are on Ubuntu you can use "overlayfs". Otherwise you need to use "native".
      snapshotter = "$( (uname -v | grep Ubuntu >/dev/null) && echo overlayfs || echo native)"
    [plugins.cri.cni]
      bin_dir = "$U7S_BASE_DIR/bin/cni"
      conf_dir = "$U7S_BASE_DIR/config/containerd/cni"
EOF
exec $(dirname $0)/nsenter.sh containerd -c $XDG_RUNTIME_DIR/usernetes/containerd.toml $@
