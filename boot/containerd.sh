#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

disable_cgroup="true"
# NOTE: /sys/fs/cgroup is namespaced, and always cgroup2 regardless of the host cgroup version.
if grep -qw memory /sys/fs/cgroup/cgroup.controllers && grep -qw cpu /sys/fs/cgroup/cgroup.controllers; then
	disable_cgroup="false"
fi

mkdir -p $XDG_RUNTIME_DIR/usernetes
cat >$XDG_RUNTIME_DIR/usernetes/containerd.toml <<EOF
version = 2
root = "$XDG_DATA_HOME/usernetes/containerd"
state = "$XDG_RUNTIME_DIR/usernetes/containerd"
[grpc]
  address = "$XDG_RUNTIME_DIR/usernetes/containerd/containerd.sock"
[proxy_plugins]
  [proxy_plugins."fuse-overlayfs"]
    type = "snapshot"
    address = "$XDG_RUNTIME_DIR/usernetes/containerd/fuse-overlayfs.sock"
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    disable_cgroup = ${disable_cgroup}
    disable_apparmor = true
    restrict_oom_score_adj = true
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "fuse-overlayfs"
      default_runtime_name = "crun"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun.options]
            BinaryName = "crun"
            SystemdCgroup = false
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
EOF
exec containerd -c $XDG_RUNTIME_DIR/usernetes/containerd.toml $@
