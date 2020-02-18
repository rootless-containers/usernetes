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
x SLIRP4NETNS rootless-containers/slirp4netns
x CONTAINERD containerd/containerd
x CRIO cri-o/cri-o
x KUBERNETES kubernetes/kubernetes
