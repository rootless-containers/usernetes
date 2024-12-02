#!/bin/bash
set -eux -o pipefail

: "${LIMACTL:=limactl --tty=false}"
: "${LIMA_TEMPLATE:=template://default}"
: "${CONTAINER_ENGINE:=docker}"
: "${LOCKDOWN_SUDO:=1}"

guest_home="/home/${USER}.linux"

# Create Rootless Docker hosts
for host in host0 host1; do
	# Set --plain to minimize Limaism
	${LIMACTL} start --plain --network lima:user-v2 --name="${host}" "${LIMA_TEMPLATE}"
	${LIMACTL} copy -r "$(pwd)" "${host}:${guest_home}/usernetes"
	${LIMACTL} shell "${host}" sudo CONTAINER_ENGINE="${CONTAINER_ENGINE}" "${guest_home}/usernetes/init-host/init-host.root.sh"
	# Terminate the current session so that the cgroup delegation takes an effect. This command exits with status 255 as SSH terminates.
	${LIMACTL} shell "${host}" sudo loginctl terminate-user "${USER}" || true
	${LIMACTL} shell "${host}" sudo loginctl enable-linger "${USER}"
	if [ "${LOCKDOWN_SUDO}" = "1" ]; then
		# Lockdown sudo to ensure rootless-ness
		${LIMACTL} shell "${host}" sudo sh -euxc 'rm -rf /etc/sudoers.d/*-cloud-init-users'
	fi
	${LIMACTL} shell "${host}" CONTAINER_ENGINE="${CONTAINER_ENGINE}" "${guest_home}/usernetes/init-host/init-host.rootless.sh"
done

# Launch a Kubernetes node inside a Rootless Docker host
for host in host0 host1; do
	${LIMACTL} shell "${host}" CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" up
done

# Bootstrap a cluster with host0
${LIMACTL} shell host0 CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" kubeadm-init install-flannel kubeconfig join-command

# Let host1 join the cluster
${LIMACTL} copy host0:~/usernetes/join-command host1:~/usernetes/join-command
${LIMACTL} shell host1 CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" kubeadm-join
${LIMACTL} shell host0 CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" sync-external-ip

# Enable kubectl
ssh -q -f -N -L 6443:127.0.0.1:6443 -F ~/.lima/host0/ssh.config lima-host0
${LIMACTL} copy host0:${guest_home}/usernetes/kubeconfig ./kubeconfig
KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG
kubectl get nodes -o wide
kubectl get pods -A
