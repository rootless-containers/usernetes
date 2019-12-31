#!/bin/bash
set -eu -o pipefail
if [[ $# -ne 2 ]]; then
	echo "Usage: $0 IMAGE ARG"
	exit 1
fi

image=$1
arg=$2

container="$(echo $1-$2 | sed -e s@/@-@g)"

set -x
docker run -d --name $container --privileged $image $arg
function cleanup() {
	docker rm -f $container
}
trap cleanup EXIT
docker exec $container ./boot/nsenter.sh echo rootlesskit ready
timeout 60 sh -ex -c "until test \$(docker exec $container ./kubectl.sh get nodes -o name | grep ^node/ | wc -l) -gt 0; do sleep 5; done" || docker logs $container
function k(){
	docker exec -it $container ./kubectl.sh $@
}
k get nodes -o wide
k get nodes -o yaml
k run --rm -i --image busybox --restart=Never hello echo hello $container
k get nodes -o wide
