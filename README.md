# Usernetes: Kubernetes without the root privileges (Generation 2)

Usernetes (Gen2) deploys a Kubernetes cluster on [Rootless Docker hosts](https://rootlesscontaine.rs/getting-started/docker/).

> **Note**
>
> Usernetes (Gen2) has *significantly* diverged from the original Usernetes (Gen1),
> which did not rely on Rootless Docker hosts.
>
> See the [`gen1`](https://github.com/rootless-containers/usernetes/tree/gen1) branch for
> the original Usernetes (Gen1).

Usernetes (Gen2) is similar to [Rootless `kind`](https://kind.sigs.k8s.io/docs/user/rootless/) and [Rootless minikube](https://minikube.sigs.k8s.io/docs/drivers/docker/),
but Usernetes (Gen 2) supports creating a cluster with multiple hosts.

## Components
- Cluster configuration: kubeadm
- CRI: containerd
- OCI: runc
- CNI: Flannel

## Requirements

- [Rootless Docker](https://rootlesscontaine.rs/getting-started/docker/)

- cgroup v2 delegation:
```bash
sudo mkdir -p /etc/systemd/system/user@.service.d

cat <<EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF

sudo systemctl daemon-reload
```

- Kernel modules:
```
sudo modprobe vxlan
```

Using Ubuntu 22.04 hosts is recommended.

## Usage
See `make help`.

```bash
# Bootstrap a cluster
make up
make kubeadm-init
make install-flannel

# Enable kubectl
make kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get pods -A

# Multi-host
make join-command
scp join-command another-host:~/usernetes
ssh another-host make -C ~/usernetes up kubeadm-join

# Debug
make logs
make shell
make down-v
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```
