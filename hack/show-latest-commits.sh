#!/bin/bash
set -eu -o pipefail

x() {
	name=$1
	repo=$2
	revision=$3
	json=$(curl -s https://api.github.com/repos/${repo}/commits/${revision})
	sha=$(echo $json | jq -r .sha)
	date=$(echo $json | jq -r .commit.committer.date)
	echo "# ${date}"
	echo "ARG ${name}_COMMIT=${sha}"
}

x ROOTLESSKIT rootless-containers/rootlesskit master
x CONTAINERD containerd/containerd main
x CRIO cri-o/cri-o master
# x KUBE_NODE kubernetes/kubernetes master
