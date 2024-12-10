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

- One of the following host operating system:

|Host operating system|Minimum version|
|---------------------|---------------|
|Ubuntu (recommended) |22.04          |
|Rocky Linux          |9              |
|AlmaLinux            |9              |
|Fedora               |(?)            |

- One of the following container engines:

|Container Engine                                                                    |Minimum version|
|------------------------------------------------------------------------------------|---------------|
|[Rootless Docker](https://rootlesscontaine.rs/getting-started/docker/) (recommended)|v20.10         |
|[Rootless Podman](https://rootlesscontaine.rs/getting-started/podman/)              |v4.x           |
|[Rootless nerdctl](https://rootlesscontaine.rs/getting-started/containerd/)         |v1.6           |

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

sudo tee /etc/systemd/system/user@.service.d/delegate.conf <<EOF >/dev/null
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
sudo tee /etc/sysctl.d/99-usernetes.conf <<EOF >/dev/null
net.ipv4.conf.default.rp_filter = 2
EOF

sudo sysctl --system
```

- slirp4netns, not Pasta:
```
# Podman v5 (or later) users have to change the network mode from pasta to slirp4netns.
# This step is not needed for Docker, nerdctl, and Podman v4.

mkdir -p "$HOME/.config/containers/containers.conf.d"
cat <<EOF >"$HOME/.config/containers/containers.conf.d/slirp4netns.conf"
[network]
default_rootless_network_cmd="slirp4netns"
EOF
```
<!--
pasta does not seem to work well

> 2024-12-02T17:15:40.070018488Z stderr F E1202 17:15:40.068621       1 main.go:228] Failed to create SubnetManager:
> error retrieving pod spec for 'kube-flannel/kube-flannel-ds-ms2d9': Get "https://10.96.0.1:443/api/v1/namespaces/kube-flannel/pods/kube-flannel-ds-ms2d9":
> dial tcp 10.96.0.1:443: i/o timeout
-->

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
make sync-external-ip

# Debug
make logs
make shell
make kubeadm-reset
make down-v
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

The container engine defaults to Docker.
To change the container engine, set `export CONTAINER_ENGINE=podman` or `export CONTAINER_ENGINE=nerdctl`.

### Customization

The following environment variables are recognized:

Name                  | Type    | Default value
----------------------|---------|----------------------------------------------------------------
`CONTAINER_ENGINE`    | String  | automatically resolved to "docker", "podman", or "nerdctl"
`HOST_IP`             | String  | automatically resolved to the host's IP address
`NODE_NAME`           | String  | "u7s-" + the host's hostname
`NODE_SUBNET`         | String  | "10.100.%d.0/24" (%d is computed from the hash of the hostname)
`PORT_ETCD`           | Integer | 2379
`PORT_KUBELET`        | Integer | 10250
`PORT_FLANNEL`        | Integer | 8472
`PORT_KUBE_APISERVER` | Integer | 6443

## Limitations
- Node ports cannot be exposed automatically. Edit [`docker-compose.yaml`](./docker-compose.yaml) for exposing additional node ports.
- Most of host files are not visible with `hostPath` mounts. Edit [`docker-compose.yaml`](./docker-compose.yaml) for mounting additional files.
- Some [volume drivers](https://kubernetes.io/docs/concepts/storage/volumes/) such as `nfs` do not work.

## Advanced topics
### Network
When `CONTAINER_ENGINE` is set to `nerdctl`, [bypass4netns](https://github.com/rootless-containers/bypass4netns) can be enabled for accelerating `connect(2)` syscalls.
The acceleration currently does not apply to VXLAN packets.

```bash
containerd-rootless-setuptool.sh install-bypass4netnsd
export CONTAINER_ENGINE=nerdctl
make up
```

> [!NOTE]
>
> The support for bypass4netns is still experimental

### Multi-tenancy

Multiple users on the hosts may create their own instances of Usernetes, but the port numbers have to be changed to avoid conflicts.

```bash
# Default: 2379
export PORT_ETCD=12379
# Default: 10250
export PORT_KUBELET=20250
# Default: 8472
export PORT_FLANNEL=18472
# Default: 6443
export PORT_KUBE_APISERVER=16443

make up
```

### Rootful mode
- Although Usernetes (Gen2) is designed to be used with Rootless Docker, it should work with the regular "rootful" Docker too.
  This might be useful for some people who are looking for "multi-host" version of [`kind`](https://kind.sigs.k8s.io/) and [minikube](https://minikube.sigs.k8s.io/).
