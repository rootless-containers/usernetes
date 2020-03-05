#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

export _CRIO_ROOTLESS=1
mkdir -p $XDG_DATA_HOME/containers/oci/hooks.d $XDG_CONFIG_HOME/containers $XDG_CONFIG_HOME/crio $XDG_CONFIG_HOME/crio/runc

# It looks like both crio.conf["registries"] and --registry CLI flags are needed
# https://trello.com/c/kmdF350I/521-8-registry-patch-in-cri-o
if [[ ! -f $XDG_CONFIG_HOME/crio/crio.conf ]]; then
	cat >$XDG_CONFIG_HOME/crio/crio.conf <<EOF
registries = ['registry.access.redhat.com', 'registry.fedoraproject.org', 'docker.io']
[crio.runtime]
  default_runtime = "crun"
  [crio.runtime.runtimes]
    [crio.runtime.runtimes.crun]
      runtime_path = "$U7S_BASE_DIR/bin/crun"
      runtime_root = "$XDG_RUNTIME_DIR/crio/crun"
# Dummy runc handler, as a workaround of https://github.com/cri-o/cri-o/issues/3360
    [crio.runtime.runtimes.runc]
      runtime_path = "/bin/false"
EOF
fi

# workaround: https://github.com/rootless-containers/usernetes/issues/30
if [[ ! -f $XDG_CONFIG_HOME/containers/policy.json ]]; then
	cat >$XDG_CONFIG_HOME/containers/policy.json <<EOF
{"default": [{"type": "insecureAcceptAnything"}]}
EOF
fi

exec crio \
	--signature-policy $XDG_CONFIG_HOME/containers/policy.json \
	--config $XDG_CONFIG_HOME/crio/crio.conf \
	--registry registry.access.redhat.com --registry registry.fedoraproject.org --registry docker.io \
	--conmon $U7S_BASE_DIR/bin/conmon \
	--runroot $XDG_RUNTIME_DIR/crio \
	--cni-config-dir /etc/cni/net.d \
	--cni-plugin-dir /opt/cni/bin \
	--root $XDG_DATA_HOME/containers/storage \
	--hooks-dir $XDG_DATA_HOME/containers/oci/hooks.d \
	--cgroup-manager=cgroupfs \
	--storage-driver vfs \
	$@
