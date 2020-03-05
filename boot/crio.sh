#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

export _CRIO_ROOTLESS=1
mkdir -p $XDG_CONFIG_HOME/usernetes/crio $XDG_CONFIG_HOME/usernetes/containers/oci/hooks.d

cat >$XDG_CONFIG_HOME/usernetes/containers/policy.json <<EOF
{"default": [{"type": "insecureAcceptAnything"}]}
EOF

cat >$XDG_CONFIG_HOME/usernetes/crio/crio.conf <<EOF
[crio]
  runroot = "$XDG_RUNTIME_DIR/usernetes/containers/storage"
  root = "$XDG_DATA_HOME/usernetes/containers/storage"
  version_file = "$XDG_RUNTIME_DIR/usernetes/crio/version"
  storage_driver = "overlay"
  storage_option = [
    "overlay.mount_program=$U7S_BASE_DIR/bin/fuse-overlayfs" 
  ]
  [crio.api]
    listen = "$XDG_RUNTIME_DIR/usernetes/crio/crio.sock"
  [crio.image]
    signature_policy = "$XDG_CONFIG_HOME/usernetes/containers/policy.json"
    registries = ["docker.io"]
  [crio.runtime]
    conmon = "$U7S_BASE_DIR/bin/conmon"
    hooks_dir = ["$XDG_DATA_HOME/usernetes/containers/oci/hooks.d"]
    container_exits_dir = "$XDG_RUNTIME_DIR/usernetes/crio/exits"
    container_attach_socket_dir = "$XDG_RUNTIME_DIR/usernetes/crio"
    namespaces_dir = "$XDG_RUNTIME_DIR/usernetes/crio/ns"
    cgroup_manager = "cgroupfs"
    default_runtime = "crun"
    [crio.runtime.runtimes]
      [crio.runtime.runtimes.crun]
        runtime_path = "$U7S_BASE_DIR/bin/crun"
        runtime_root = "$XDG_RUNTIME_DIR/crio/crun"
# Dummy runc handler, as a workaround of https://github.com/cri-o/cri-o/issues/3360
      [crio.runtime.runtimes.runc]
        runtime_path = "/bin/false"
  [crio.network]
    network_dir = "/etc/cni/net.d/"
    plugin_dirs = ["/opt/cni/bin/"]
EOF

exec crio --config $XDG_CONFIG_HOME/usernetes/crio/crio.conf $@
