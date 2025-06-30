#!/bin/bash
set -eux -o pipefail

: "${LIMACTL:=limactl --tty=false}"
: "${LIMACTL_CREATE_ARGS:=}"
: "${LIMA_TEMPLATE:=template://default}"
: "${CONTAINER_ENGINE:=docker}"
: "${LOCKDOWN_SUDO:=1}"
: "${PORT_KUBE_APISERVER:=6443}"
: "${PORT_ETCD:=2379}"
: "${PORT_FLANNEL:=8472}"
: "${PORT_KUBELET:=10250}"

guest_home="/home/${USER}.linux"

if [ "$(id -u)" -le 1000 ]; then
	# In --plain mode, UID has to be >= 1000 to populate subuids
	# https://github.com/lima-vm/lima/issues/3001
	LIMACTL_CREATE_ARGS="${LIMACTL_CREATE_ARGS} --set=.user.uid=1001"
fi

# Create Rootless Docker hosts
for host in host0 host1; do
	# Set --plain to minimize Limaism
	${LIMACTL} start --plain --network lima:user-v2 --name="${host}" ${LIMACTL_CREATE_ARGS} "${LIMA_TEMPLATE}"
	${LIMACTL} copy -r "$(pwd)" "${host}:${guest_home}/usernetes"
	${LIMACTL} shell "${host}" sudo CONTAINER_ENGINE="${CONTAINER_ENGINE}" CONTAINER_ROOTFUL="${CONTAINER_ROOTFUL}" "${guest_home}/usernetes/init-host/init-host.root.sh"
	# Terminate the current session so that the cgroup delegation takes an effect. This command exits with status 255 as SSH terminates.
	${LIMACTL} shell "${host}" sudo loginctl terminate-user "${USER}" || true
	${LIMACTL} shell "${host}" sudo loginctl enable-linger "${USER}"
	if [ "${LOCKDOWN_SUDO}" = "1" ]; then
		# Lockdown sudo to ensure rootless-ness
		${LIMACTL} shell "${host}" sudo sh -euxc 'rm -rf /etc/sudoers.d/*-cloud-init-users'
	fi
	${LIMACTL} shell "${host}" CONTAINER_ENGINE="${CONTAINER_ENGINE}" CONTAINER_ROOTFUL="${CONTAINER_ROOTFUL}" "${guest_home}/usernetes/init-host/init-host.rootless.sh"
done

SERVICE_PORTS="PORT_KUBE_APISERVER=${PORT_KUBE_APISERVER} PORT_ETCD=${PORT_ETCD} PORT_FLANNEL=${PORT_FLANNEL} PORT_KUBELET=${PORT_KUBELET}"

# Launch a Kubernetes node inside a Rootless Docker host
for host in host0 host1; do
	${LIMACTL} shell "${host}" ${SERVICE_PORTS} CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" up
done

# Bootstrap a cluster with host0
${LIMACTL} shell host0 ${SERVICE_PORTS} CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" kubeadm-init install-flannel kubeconfig join-command

# Let host1 join the cluster
${LIMACTL} copy host0:~/usernetes/join-command host1:~/usernetes/join-command
${LIMACTL} shell host1 ${SERVICE_PORTS} CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" kubeadm-join
${LIMACTL} shell host0 ${SERVICE_PORTS} CONTAINER_ENGINE="${CONTAINER_ENGINE}" make -C "${guest_home}/usernetes" sync-external-ip

# Enable kubectl
ssh -q -f -N -L ${PORT_KUBE_APISERVER}:127.0.0.1:${PORT_KUBE_APISERVER} -F ~/.lima/host0/ssh.config lima-host0
${LIMACTL} copy host0:${guest_home}/usernetes/kubeconfig ./kubeconfig
KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG
kubectl get nodes -o wide
kubectl get pods -A
