#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

mkdir -p $XDG_RUNTIME_DIR/usernetes
cat >$XDG_RUNTIME_DIR/usernetes/kube-proxy-config.yaml <<EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "iptables"
clientConnection:
  kubeconfig: "$XDG_CONFIG_HOME/usernetes/node/kube-proxy.kubeconfig"
featureGates:
# EndpointSliceProxying seems to break ClusterIP: https://github.com/rootless-containers/usernetes/pull/179
  EndpointSliceProxying: false
EOF

exec $(dirname $0)/nsenter.sh kube-proxy \
	--config $XDG_RUNTIME_DIR/usernetes/kube-proxy-config.yaml \
	$@
