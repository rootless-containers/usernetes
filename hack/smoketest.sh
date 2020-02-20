#!/bin/bash
set -eu -o pipefail
if [[ $# -lt 3 ]]; then
	echo "Usage: $0 NAME IMAGE ARGS"
	exit 1
fi

cd $(realpath $(dirname $0)/..)
container=$1
image=$2
shift 2
args=$@

set -x
tmpdir=$(mktemp -d)
docker run -td --name $container -p 127.0.0.1:8080:8080 --privileged rootlesscontainers/usernetes -p 0.0.0.0:8080:8080/tcp $args
function cleanup() {
	docker rm -f $container
	rm -rf $tmpdir
}
trap cleanup EXIT

export KUBECONFIG=$(pwd)/config/localhost.kubeconfig
docker cp $container:/home/user/usernetes/bin/kubectl $tmpdir/kubectl
chmod +x $tmpdir/kubectl
kubectl=$tmpdir/kubectl

# TODO: use Dockerfile HEALTHCHECK
sleep 30
$kubectl get nodes -o wide
$kubectl get nodes -o yaml
time $kubectl run --rm -i --image busybox --restart=Never hello echo hello $container
