#!/bin/bash
# needs to be called inside the namespaces
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

export _CRIO_ROOTLESS=1

mkdir -p $XDG_CONFIG_HOME/usernetes/crio $XDG_CONFIG_HOME/usernetes/containers/oci/hooks.d

cat >$XDG_CONFIG_HOME/usernetes/containers/policy.json <<EOF
{"default": [{"type": "insecureAcceptAnything"}]}
EOF

cat >$XDG_CONFIG_HOME/usernetes/containers/registries.conf <<EOF
unqualified-search-registries=["docker.io"]
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
  [crio.runtime]
    conmon = "$U7S_BASE_DIR/bin/conmon"
    conmon_cgroup = "pod"
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
  [crio.network]
    network_dir = "/etc/cni/net.d/"
    plugin_dirs = ["/opt/cni/bin/"]
EOF

exec crio \
	--config $XDG_CONFIG_HOME/usernetes/crio/crio.conf \
	--registries-conf $XDG_CONFIG_HOME/usernetes/containers/registries.conf \
	$@
