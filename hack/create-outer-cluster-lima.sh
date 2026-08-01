#!/bin/bash
set -eux -o pipefail

# Create a two-node Kubernetes cluster to be used as the "outer" cluster
# of the Kubernetes-in-Kubernetes mode (see ../kubernetes), using Lima's
# template:k8s, and configure it for Usernetes:
# - the "usernetes" containerd runtime handler (cgroup_writable = true)
# - the "usernetes" RuntimeClass

: "${LIMACTL:=limactl --tty=false}"
: "${LIMACTL_CREATE_ARGS:=}"
: "${LIMA_TEMPLATE:=template://k8s}"

# host0 provides the control plane.
${LIMACTL} start --network lima:user-v2 --name=host0 ${LIMACTL_CREATE_ARGS} "${LIMA_TEMPLATE}"

# host1 joins the cluster of host0 as a worker, via the `url`, `token`, and
# `discoveryTokenCaCertHash` parameters of the template.
# https://lima-vm.io/docs/examples/containers/kubernetes/
join_command="$(${LIMACTL} shell host0 sudo kubeadm token create --print-join-command | tr -d '\r')"
# join_command is like "kubeadm join <URL> --token <TOKEN> --discovery-token-ca-cert-hash <HASH>"
url="$(echo "${join_command}" | awk '{print $3}')"
token="$(echo "${join_command}" | awk '{for (i = 1; i < NF; i++) if ($i == "--token") print $(i+1)}')"
hash="$(echo "${join_command}" | awk '{for (i = 1; i < NF; i++) if ($i == "--discovery-token-ca-cert-hash") print $(i+1)}')"
${LIMACTL} start --network lima:user-v2 --name=host1 ${LIMACTL_CREATE_ARGS} \
	--param url="${url}" --param token="${token}" --param discoveryTokenCaCertHash="${hash}" \
	"${LIMA_TEMPLATE}"

# Define the "usernetes" containerd runtime handler with
# `cgroup_writable = true` (containerd >= 2.1), so that systemd inside
# the node pods can manage its own (namespaced) cgroups.
# /etc/containerd/conf.d/*.toml is imported by the containerd config of
# template:k8s.
#
# Also provide a read-write sysfs instance at /run/usernetes/sysfs, to be
# mounted into the node pods; needed for creating privileged pods in the
# inner cluster (see ../kubernetes/README.md).
# `unshare --net` detaches the instance from the netns of the host, so it
# does not expose the network devices of the host.
for host in host0 host1; do
	${LIMACTL} shell "${host}" sudo sh -euxc 'mkdir -p /run/usernetes/sysfs
mountpoint -q /run/usernetes/sysfs || unshare --net mount -t sysfs -o nosuid,nodev,noexec sysfs /run/usernetes/sysfs
cat >/etc/containerd/conf.d/usernetes.toml <<EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.usernetes]
          runtime_type = "io.containerd.runc.v2"
          cgroup_writable = true
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.usernetes.options]
            SystemdCgroup = true
EOF
systemctl restart containerd'
done

KUBECONFIG="${HOME}/.lima/host0/copied-from-guest/kubeconfig.yaml"
export KUBECONFIG
# The `kubeadm join` on host1 may still be in progress when `limactl start`
# returns, so wait for the node to be registered before waiting for Ready.
for _ in $(seq 1 60); do
	test "$(kubectl get nodes --no-headers 2>/dev/null | wc -l)" -ge 2 && break
	sleep 5
done
kubectl wait --for=condition=Ready node --all --timeout=5m
kubectl get nodes -o wide

# Create the "usernetes" RuntimeClass, corresponding to the containerd
# runtime handler defined above. To be used as U7S_RUNTIME_CLASS_NAME.
kubectl apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: usernetes
handler: usernetes
EOF

echo "# The outer cluster is ready. Run the following command by yourself:"
echo "export KUBECONFIG=${KUBECONFIG}"
