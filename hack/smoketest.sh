#!/bin/bash
set -eu -o pipefail
if [[ $# -ne 2 ]]; then
	echo "Usage: $0 IMAGE ARG"
	exit 1
fi

image=$1
arg=$2

container="$1-$2"

set -x
docker run -d --name $container --privileged $image $arg
function cleanup() {
	docker rm -f $container
}
trap cleanup EXIT
sleep 10
docker exec -it $container ./kubectl.sh get nodes -o yaml
docker exec -it $container ./kubectl.sh run --rm -i --image busybox --restart=Never hello echo hello
