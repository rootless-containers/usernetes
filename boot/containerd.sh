#!/bin/bash
# needs to be called inside the namespaces
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

disable_cgroup="true"
if [[ "$U7S_CGROUP_ENABLED" = "1" ]]; then
	disable_cgroup="false"
else
	log::warning "Running without cgroup. This mode is deprecated and will be removed in a future release of Usernetes."
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
    disable_hugetlb_controller = true
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "fuse-overlayfs"
      default_runtime_name = "crun"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun.options]
            BinaryName = "crun"
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
EOF
exec containerd -c $XDG_RUNTIME_DIR/usernetes/containerd.toml $@
