#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/../..)
source $U7S_BASE_DIR/common/common.inc.sh

mkdir -p $XDG_RUNTIME_DIR/usernetes/calico
cat >$XDG_RUNTIME_DIR/usernetes/calico/custom-resources.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 10.88.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
  kubeletVolumePluginPath: "$XDG_DATA_HOME/usernetes/kubelet"
  nonPrivileged: Enabled
  flexVolumePath: "$XDG_DATA_HOME/usernetes/kubelet-plugins-exec"

---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

exec $U7S_BASE_DIR/boot/nsenter.sh kubectl \
	create -f "$XDG_RUNTIME_DIR/usernetes/calico/custom-resources.yaml"