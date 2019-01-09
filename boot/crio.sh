#!/bin/bash
source $(dirname $0)/../common/common.inc.sh
nsenter::main $0 $@

export _CRIO_ROOTLESS=1
mkdir -p $XDG_DATA_HOME/containers $XDG_CONFIG_HOME/containers $XDG_CONFIG_HOME/crio

# It looks like both crio.conf["registries"] and --registry CLI flags are needed
# https://trello.com/c/kmdF350I/521-8-registry-patch-in-cri-o
if [[ ! -f $XDG_CONFIG_HOME/crio/crio.conf ]]; then
	cat >$XDG_CONFIG_HOME/crio/crio.conf <<EOF
registries = ['registry.access.redhat.com', 'registry.fedoraproject.org', 'docker.io']
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
	--runtimes runc:$U7S_BASE_DIR/bin/runc \
	--cni-config-dir $U7S_BASE_DIR/config/crio/cni \
	--cni-plugin-dir $U7S_BASE_DIR/bin/cni \
	--root $XDG_DATA_HOME/containers/storage \
	--cgroup-manager=cgroupfs \
	--storage-driver vfs \
	$@
