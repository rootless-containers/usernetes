#!/bin/bash
set -eux -o pipefail

# Create Rootless Docker hosts
./hack/create-hosts-lxd.sh "${HOME}/.u7s-ci-hosts" host0 host1
SCP="scp -F ${HOME}/.u7s-ci-hosts/ssh_config"
SSH="ssh -F ${HOME}/.u7s-ci-hosts/ssh_config"
for host in host0 host1; do
	$SCP -r "$(pwd)" "${host}:~/usernetes"
	$SSH "${USER}-sudo@${host}" sudo "~${USER}/usernetes/hack/init-host.root.sh"
	$SSH "${USER}-sudo@${host}" sudo loginctl enable-linger "${USER}"
	$SSH "${host}" ~/usernetes/hack/init-host.rootless.sh
done

# Launch a Kubernetes node inside a Rootless Docker host
for host in host0 host1; do
	$SSH "${host}" make -C ~/usernetes up
done

# Bootstrap a cluster with host0
$SSH host0 make -C ~/usernetes kubeadm-init install-flannel kubeconfig join-command

# Let host1 join the cluster
$SCP host0:~/usernetes/join-command host1:~/usernetes/join-command
$SSH host1 make -C ~/usernetes kubeadm-join

# Enable kubectl
$SCP host0:~/usernetes/kubeconfig ./kubeconfig
KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG
kubectl get nodes -o wide
kubectl get pods -A
