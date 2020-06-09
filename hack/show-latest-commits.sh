#!/bin/bash
set -eu -o pipefail

x() {
	name=$1
	repo=$2
	revision=master
	json=$(curl -s https://api.github.com/repos/${repo}/commits/${revision})
	sha=$(echo $json | jq -r .sha)
	date=$(echo $json | jq -r .commit.committer.date)
	echo "# ${date}"
	echo "ARG ${name}_COMMIT=${sha}"
}

x ROOTLESSKIT rootless-containers/rootlesskit
x CONTAINERD containerd/containerd
x CONTAINERD_FUSE_OVERLAYFS AkihiroSuda/containerd-fuse-overlayfs
x CRIO cri-o/cri-o
# Only Kube node needs patching. For Kube master, we download pre-built binaries.
x KUBE_NODE kubernetes/kubernetes
