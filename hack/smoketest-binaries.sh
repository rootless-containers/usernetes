#!/bin/bash
source $(realpath $(dirname $0))/smoketest-common.inc.sh
cd $(realpath $(dirname $0)/..)
function cleanup() {
	$(pwd)/uninstall.sh || true
	$(pwd)/cleanup.sh || true
}
trap cleanup EXIT

set -x
./install.sh $@

./rootlessctl.sh add-ports 127.0.0.1:8080:8080/tcp
export KUBECONFIG=$(pwd)/config/localhost.kubeconfig
export PATH=$(pwd)/bin:$PATH

if ! timeout 60 sh -exc 'until [ $(kubectl get nodes | grep "Ready" | grep -v "NotReady" | wc -l) = "1" ]; do sleep 10; done'; then
	ERROR "Node is not ready."
	set -x
	set +eu
	systemctl --user status u7s-kube-apiserver
	kubectl get nodes -o wide
	kubectl get nodes -o yaml
	journalctl -xe --no-pager
	exit 1
fi

kubectl get nodes -o wide
if ! timeout 60 kubectl run --rm -i --image busybox --restart=Never hello echo hello; then
	ERROR "Pod is not ready."
	set -x
	set +eu
	kubectl get pods -o yaml
	kubectl get nodes -o yaml
	journalctl -xe --no-pager
	exit 1
fi
