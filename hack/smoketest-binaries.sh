#!/bin/bash
source $(realpath $(dirname $0))/smoketest-common.inc.sh
cd $(realpath $(dirname $0)/..)
function cleanup() {
	$(pwd)/show-status.sh
	$(pwd)/uninstall.sh || true
	eval $($(pwd)/show-cleanup-command.sh) || true
}
trap cleanup EXIT

set -x
./install.sh $@

export KUBECONFIG=$HOME/.config/usernetes/master/admin-localhost.kubeconfig
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

smoketest_dns

if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
	if echo $@ | grep -qw crio; then
		INFO "Skipping resource limitation tests (CRI-O does not support cgroup in rootless)"
	else
		INFO "Detected cgroup v2 and containerd. Running resource limitation tests"
		smoketest_limits
	fi
else
	INFO "Skipping resource limitation tests (delegation is unsupported on cgroup v1 hosts)"
fi
