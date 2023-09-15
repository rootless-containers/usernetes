# Usernetes: Kubernetes without the root privileges (Generation 2)

Usernetes (Gen2) deploys a Kubernetes cluster inside [Rootless Docker](https://rootlesscontaine.rs/getting-started/docker/),
so as to mitigate potential container-breakout vulnerabilities.

> **Note**
>
> Usernetes (Gen2) has *significantly* diverged from the original Usernetes (Gen1),
> which did not require Rootless Docker to be installed on hosts.
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

- Host OS should be one of the following:
  - Ubuntu 22.04 (recommended)
  - Rocky Linux 9
  - AlmaLinux 9

- [Rootless Docker](https://rootlesscontaine.rs/getting-started/docker/):
```bash
curl -o install.sh -fsSL https://get.docker.com
sudo sh install.sh
dockerd-rootless-setuptool.sh install
```

- systemd lingering:
```bash
sudo loginctl enable-linger $(whoami)
```

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
sudo tee /etc/modules-load.d/usernetes.conf <<EOF >/dev/null
br_netfilter
vxlan
EOF

sudo systemctl restart systemd-modules-load.service
```

- sysctl:
```
cat tee /etc/sysctl.d/99-usernetes.conf <<EOF >/dev/null
net.ipv4.conf.default.rp_filter = 2
EOF

sudo sysctl --system
```

Use scripts in [`./init-host`](./init-host) for automating these steps.

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

## Limitations
- Node ports cannot be exposed automatically. Edit [`docker-compose.yaml`](./docker-compose.yaml) for exposing additional node ports.
- Most of host files are not visible with `hostPath` mounts. Edit [`docker-compose.yaml`](./docker-compose.yaml) for mounting additional files.
- Some [volume drivers](https://kubernetes.io/docs/concepts/storage/volumes/) such as `nfs` do not work.

<!--
## Advanced topics
- Although Usernetes (Gen2) is designed to be used with Rootless Docker, it should work with the regular "rootful" Docker too.
  This might be useful for some people who are looking for "multi-host" version of [`kind`](https://kind.sigs.k8s.io/) and [minikube](https://minikube.sigs.k8s.io/).
-->
<!-- ↑FIXME: "rootful" support is broken: https://github.com/rootless-containers/usernetes/issues/297 -->
