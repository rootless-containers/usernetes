#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

mkdir -p $XDG_RUNTIME_DIR/usernetes
cat >$XDG_RUNTIME_DIR/usernetes/kubelet-config.yaml <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
volumePluginDir: $XDG_DATA_HOME/usernetes/kubelet-plugins-exec
authentication:
  anonymous: 
    enabled: false
  x509:
    clientCAFile: "$XDG_CONFIG_HOME/usernetes/node/ca.pem"
tlsCertFile: "$XDG_CONFIG_HOME/usernetes/node/node.pem"
tlsPrivateKeyFile: "$XDG_CONFIG_HOME/usernetes/node/node-key.pem"
clusterDomain: "cluster.local"
clusterDNS:
  - "10.0.0.53"
failSwapOn: false
featureGates:
  KubeletInUserNamespace: true
evictionHard:
  nodefs.available: "3%"
localStorageCapacityIsolation: false
cgroupDriver: "cgroupfs"
cgroupsPerQOS: true
enforceNodeAllocatable: []
EOF

exec $(dirname $0)/nsenter.sh kubelet \
	--cert-dir $XDG_CONFIG_HOME/usernetes/pki \
	--root-dir $XDG_DATA_HOME/usernetes/kubelet \
	--kubeconfig $XDG_CONFIG_HOME/usernetes/node/node.kubeconfig \
	--config $XDG_RUNTIME_DIR/usernetes/kubelet-config.yaml \
	$@

# Notes
# evictrionHard: Relax disk pressure taint for CI
# localStorageCapacityIsolation=false: workaround for "Failed to start ContainerManager failed to get rootfs info" error on Fedora 32: https://github.com/rootless-containers/usernetes/pull/157#issuecomment-621008594
