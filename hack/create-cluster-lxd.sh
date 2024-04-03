#!/bin/bash
set -eux -o pipefail

: "${CONTAINER_ENGINE:=docker}"

# Create Rootless Docker hosts
./hack/create-hosts-lxd.sh "${HOME}/.u7s-ci-hosts" host0 host1
SCP="scp -F ${HOME}/.u7s-ci-hosts/ssh_config"
SSH="ssh -F ${HOME}/.u7s-ci-hosts/ssh_config"
for host in host0 host1; do
	$SCP -r "$(pwd)" "${host}:~/usernetes"
	$SSH "${USER}-sudo@${host}" sudo CONTAINER_ENGINE="${CONTAINER_ENGINE}" "~${USER}/usernetes/init-host/init-host.root.sh"
	$SSH "${USER}-sudo@${host}" sudo loginctl enable-linger "${USER}"
	$SSH "${host}" CONTAINER_ENGINE="${CONTAINER_ENGINE}" ~/usernetes/init-host/init-host.rootless.sh
done

# Launch a Kubernetes node inside a Rootless Docker host
for host in host0 host1; do
	$SSH "${host}" CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C ~/usernetes up
done

# Bootstrap a cluster with host0
$SSH host0 CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C ~/usernetes kubeadm-init install-flannel kubeconfig join-command

# Let host1 join the cluster
$SCP host0:~/usernetes/join-command host1:~/usernetes/join-command
$SSH host1 CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C ~/usernetes kubeadm-join
$SSH host0 CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C ~/usernetes sync-external-ip

# Enable kubectl
$SCP host0:~/usernetes/kubeconfig ./kubeconfig
sed -i -e "s/127.0.0.1/$($SSH host0 ip --json route get 1 | jq -r .[0].prefsrc)/g" ./kubeconfig
KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG
kubectl get nodes -o wide
kubectl get pods -A
