# Kubernetes-in-Kubernetes (experimental)

Usernetes can be deployed inside an existing Kubernetes cluster,
as [UserNS-enabled pods](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/)
(`hostUsers: false`), so as to mitigate potential container-breakout
vulnerabilities of the inner cluster.

This is the "Kubernetes-in-Kubernetes" analog of running Usernetes inside
Rootless Docker: the node pods run in their own user namespaces, so "root"
inside a node pod does not correspond to the root on the host.
The node pods do **not** use `privileged: true`.
Instead, they are granted all the *namespaced* capabilities, an unmasked
procfs, and unconfined seccomp/AppArmor profiles, which do not provide the
real root privileges on the hosts.

> [!WARNING]
>
> This mode is experimental.

## Requirements

Requirements for the "outer" (host) Kubernetes cluster:

- Kubernetes v1.33 or later is recommended.
  The [`UserNamespacesSupport`](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/)
  feature gate is enabled by default since v1.33 (GA in v1.36).
  On v1.30 - v1.32, the feature gate has to be enabled manually.
  The [`ProcMountType`](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
  feature gate is also required for `procMount: Unmasked`.
- Node kernel >= 6.3: the kubelet mounts the volumes of a UserNS-enabled pod
  with [idmapped mounts](https://lwn.net/Articles/896255/), and tmpfs (which
  backs the `emptyDir` volumes with `medium: Memory`, plus `secret`,
  `configMap`, `projected`, and `downwardAPI` volumes) only gained idmapped
  mounts support in Linux 6.3. The filesystem backing the kubelet directory
  (`/var/lib/kubelet`) has to support idmapped mounts as well.
- CRI: containerd >= 2.1, or CRI-O >= 1.25.
- OCI: runc >= 1.2, or crun >= 1.9.
- The CRI has to mount `/sys/fs/cgroup` of the node pods **read-write**, so
  that systemd inside them can manage its own (namespaced) cgroups; the OCI
  runtime then chowns the cgroup to the mapped root of the user namespace.
  This is *not* the default behavior for unprivileged pods:
  - containerd: define a dedicated runtime handler with
    [`cgroup_writable = true`](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)
    (containerd >= 2.1), restart containerd, and expose the handler to the
    pods as a RuntimeClass:
    ```toml
    # /etc/containerd/config.toml (version = 3)
    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.usernetes]
      runtime_type = "io.containerd.runc.v2"
      cgroup_writable = true
      [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.usernetes.options]
        SystemdCgroup = true
    ```
    ```yaml
    apiVersion: node.k8s.io/v1
    kind: RuntimeClass
    metadata:
      name: usernetes
    handler: usernetes
    ```
    Then set `U7S_RUNTIME_CLASS_NAME=usernetes` so that the node pods use the
    RuntimeClass. Setting `cgroup_writable = true` on the default "runc"
    handler works too, but is not recommended, as it would affect all the
    unprivileged pods on the nodes.
    For k3s, see
    [`../.github/workflows/reusable-k8s-in-k8s.yaml`](../.github/workflows/reusable-k8s-in-k8s.yaml).
  - CRI-O: allow the `cgroup2-mount-hierarchy-rw.crio.io` annotation
    (already set in [`./usernetes.yaml`](./usernetes.yaml)) via
    [`allowed_annotations`](https://github.com/cri-o/cri-o/blob/main/docs/crio.conf.5.md)
    in the runtime config, preferably on a dedicated runtime handler as well
    (untested).
- The `vxlan` and `br_netfilter` kernel modules loaded on the nodes
  (see [`../init-host`](../init-host)).
- (Optional) To create privileged pods in the inner cluster, the nodes have
  to provide an extra read-write sysfs instance at `/run/usernetes/sysfs`:
  ```bash
  sudo mkdir -p /run/usernetes/sysfs
  sudo unshare --net mount -t sysfs -o nosuid,nodev,noexec sysfs /run/usernetes/sysfs
  ```
  The kernel allows mounting a fresh read-write sysfs (as needed by runc for
  a privileged pod of the inner cluster) in a mount namespace owned by a
  user namespace only when the mount namespace already contains a
  fully-visible read-write sysfs instance, while the `/sys` of the node pods
  is mounted read-only by the CRI of the outer cluster. The instance is
  provided by the host (mounted into the node pods via a `hostPath` volume;
  see [`./usernetes.yaml`](./usernetes.yaml)), as the node pods cannot mount
  it by themselves. `unshare --net` detaches the instance from the network
  namespace of the host, so it does not expose the network devices of the
  host; sysfs cannot be written by the node pods anyway, as the files are
  owned by the "real" root. Without this mount, everything else still works;
  only the creation of privileged pods in the inner cluster fails
  (see [issue #396](https://github.com/rootless-containers/usernetes/issues/396)).
- `net.ipv4.conf.default.rp_filter` should be 0 (disabled) or 2 (loose) on the
  nodes; the entrypoint of the node pods also tries to relax it by itself.
- The Pod Security admission of the namespace must allow the `privileged`
  profile, as the node pods opt out of several restrictions of the `baseline`
  profile (capabilities, procMount, seccomp/AppArmor).
  The pods are still isolated by user namespaces.

Requirements for the client:

- `kubectl` configured for the outer cluster
- `envsubst` (GNU gettext)
- GNU make

## Usage

The node image defaults to `ghcr.io/rootless-containers/usernetes:master`,
which is built from the top-level [`Dockerfile`](../Dockerfile) and pushed to
GHCR by the CI ([`../.github/workflows/image.yaml`](../.github/workflows/image.yaml))
on every push to the master branch.
The image can be built and pushed manually too, to a registry that is
accessible from the outer cluster:

```bash
cd ..
docker build -t <REGISTRY>/usernetes:latest .
docker push <REGISTRY>/usernetes:latest
cd kubernetes
export U7S_IMAGE=<REGISTRY>/usernetes:latest
```

Bootstrap a cluster (see `make help`):

```bash
# Bootstrap a cluster with 1 control plane pod and ${U7S_WORKER_REPLICAS} (default: 1) worker pods
make up
make kubeadm-init
make install-flannel
make kubeadm-join

# Enable kubectl
make kubeconfig
make port-forward   # Run in a separate terminal
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get pods -A

# Debug
make logs
make shell
make down
```

The following environment variables are recognized:

Name                            | Type    | Default value
--------------------------------|---------|-----------------------------------------------
`U7S_IMAGE`                     | String  | "ghcr.io/rootless-containers/usernetes:master"
`U7S_NAMESPACE`                 | String  | "usernetes"
`U7S_RUNTIME_CLASS_NAME`        | String  | "" (the default runtime handler of the outer cluster; see the requirements above)
`U7S_WORKER_REPLICAS`           | Integer | 1
`U7S_POD_SUBNET`                | String  | "10.200.0.0/16" (must not overlap with the subnets of the outer cluster)
`U7S_SERVICE_SUBNET`            | String  | "10.201.0.0/16" (must not overlap with the subnets of the outer cluster)
`U7S_KUBE_APISERVER_LOCAL_PORT` | Integer | 6443 (set to another port when 127.0.0.1:6443 is already taken, e.g., by the outer cluster)

## How it works

- The node pods are created as two StatefulSets (`u7s-control-plane` and
  `u7s-worker`) with `hostUsers: false`, plus a headless Service `u7s` that
  provides stable DNS names for the pods
  (`<pod>.u7s.<namespace>.svc.cluster.local`).
- `HOST_IP` and `NODE_IP` are set to the IP address of the pod itself, as the
  pods can reach each other directly; no port needs to be published to the
  hosts. Flannel of the inner cluster runs VXLAN on top of the pod network of
  the outer cluster.
- The pod and service subnets of the inner cluster default to 10.200.0.0/16
  and 10.201.0.0/16, unlike in the Docker Compose mode (10.244.0.0/16 and
  10.96.0.0/16): the subnets of the inner cluster must not overlap with the
  subnets of the outer cluster, or the routes installed by Flannel of the
  inner cluster would shadow the node pods of the outer cluster.
- `make kubeadm-init` patches the kube-proxy DaemonSet of the inner cluster
  to drop `privileged: true` (in favor of `NET_ADMIN` and `NET_RAW`):
  a privileged pod with `hostNetwork` cannot be created inside a userns node
  pod, as mounting a fresh sysfs requires the network namespace to be owned
  by the user namespace, while the network namespace of the node pod is
  created by the CRI of the outer cluster.
- Unlike Docker named volumes, Kubernetes `emptyDir` volumes are not
  initialized with the image content, so an init container populates the
  `/etc`, `/opt`, and `/var` volumes before they are mounted over the image
  content.
- The image contains a copy of the Usernetes source tree in `/usernetes`
  (bind-mounted from the host in the Docker Compose mode).

## Multi-tenancy

Multiple inner clusters can be created in the same outer cluster by using
different namespaces:

```bash
export U7S_NAMESPACE=usernetes2
# Change the port (default: 6443) for each of the tenants
export U7S_KUBE_APISERVER_LOCAL_PORT=26443

make up
make kubeadm-init
make install-flannel
make kubeadm-join
```

- The node pods of different tenants never share UID ranges, even on the same
  node: the kubelet allocates a distinct range of 65536 UIDs/GIDs to every
  UserNS-enabled pod (`/etc/subuid` of the hosts is not involved).
- The pod and service subnets (`U7S_POD_SUBNET` and `U7S_SERVICE_SUBNET`) do
  not need to differ across the tenants: these subnets exist only inside the
  network namespaces of the node pods. They just must not overlap with the
  subnets of the outer cluster.
- The RuntimeClass (`U7S_RUNTIME_CLASS_NAME`) is cluster-scoped and is shared
  by the tenants.

## Limitations

- The state of the inner cluster is stored on `emptyDir` volumes and does not
  survive the recreation of the node pods. Persistent volumes
  (`volumeClaimTemplates`) are deliberately not used yet: the IP addresses of
  the pods change across restarts, which invalidates the certificates and the
  etcd configuration of the inner cluster anyway, so persisting the state
  would just prevent the recreated pods from starting cleanly. Recreate the
  cluster (`make down up kubeadm-init ...`) after the node pods are recreated.
  Switching to PVCs may be revisited in the future, along with regenerating
  the IP-dependent state on boot.
- Node ports of the inner cluster are not exposed automatically.
  `kubectl port-forward` to the node pods can be used instead.
- Privileged pods of the inner cluster need the extra sysfs instance on the
  hosts (see the requirements above). Privileged pods with `hostNetwork`
  get a read-only `/sys` (a bind mount of the `/sys` of the node pod,
  created by runc in place of a fresh read-write sysfs): mounting a fresh
  sysfs requires the network namespace to be owned by the user namespace,
  while the network namespace of the node pod is created by the CRI of the
  outer cluster (see also the comment on `patch-kube-proxy` in
  [`./Makefile`](./Makefile)).
- Most of the limitations of the Docker Compose mode
  (see the top-level [`README.md`](../README.md)) apply to this mode too.
- The `/lib/modules` and `/boot` directories of the hosts are mounted into the
  node pods with read-only `hostPath` volumes, just for checking the presence
  of the kernel modules and for reading the kernel config in the preflight
  checks of kubeadm. The volumes can be removed from
  [`usernetes.yaml`](./usernetes.yaml) if `hostPath` volumes are prohibited in
  the outer cluster (`kubeadm-init` and `kubeadm-join` would then need
  `--ignore-preflight-errors=SystemVerification`).

## Testing with k3s

The CI (see [`../.github/workflows/reusable-k8s-in-k8s.yaml`](../.github/workflows/reusable-k8s-in-k8s.yaml))
smoke-tests this mode with [k3s](https://k3s.io/) as the outer cluster,
with a dedicated "usernetes" runtime handler (`cgroup_writable = true`)
defined in the containerd of k3s and exposed as the "usernetes" RuntimeClass.
The same steps can be used locally, on a host that satisfies the kernel
requirements above. Note that k3s occupies 127.0.0.1:6443 for the API server
of the outer cluster, so the API server of the inner cluster has to be
forwarded to another local port:

```bash
docker build -t usernetes:ci ..
docker save usernetes:ci | sudo k3s ctr images import -
export U7S_IMAGE=usernetes:ci U7S_RUNTIME_CLASS_NAME=usernetes U7S_KUBE_APISERVER_LOCAL_PORT=16443
make up
make kubeadm-init
make install-flannel
make kubeadm-join
```

## Testing with Lima (multi-node)

[`../hack/create-outer-cluster-lima.sh`](../hack/create-outer-cluster-lima.sh)
creates a two-node outer cluster with [Lima](https://lima-vm.io/)'s
`template:k8s`, with the "usernetes" runtime handler and RuntimeClass
configured. The node pods are then spread across the outer nodes
(see `topologySpreadConstraints` in [`./usernetes.yaml`](./usernetes.yaml)),
so the inner Flannel runs VXLAN across the outer nodes.
The CI also tests this mode; see
[`../.github/workflows/reusable-k8s-in-k8s.yaml`](../.github/workflows/reusable-k8s-in-k8s.yaml).

```bash
./hack/create-outer-cluster-lima.sh
export KUBECONFIG=$HOME/.lima/host0/copied-from-guest/kubeconfig.yaml
export U7S_IMAGE=usernetes:ci U7S_RUNTIME_CLASS_NAME=usernetes U7S_KUBE_APISERVER_LOCAL_PORT=16443
```

## Troubleshooting

- Pod fails with `user namespaces are not supported`:
  make sure that the feature gate, the CRI, the OCI runtime, and the kernel
  of the outer cluster satisfy the requirements above.
- Node pod keeps restarting, with
  `Failed to create /init.scope control group: Read-only file system`
  in `kubectl logs` (the message may only appear with `tty: true`):
  `/sys/fs/cgroup` is mounted read-only in the pod, and systemd cannot manage
  its cgroups. Configure the CRI to mount the cgroups read-write
  (`cgroup_writable = true` for containerd, on a dedicated runtime handler
  selected via `U7S_RUNTIME_CLASS_NAME`; see the requirements above).
- Pod is rejected due to `procMount`:
  make sure that the `ProcMountType` feature gate is enabled.
- Pod is rejected by the Pod Security admission:
  make sure that the namespace allows the `privileged` profile. The manifest
  labels the namespace with `pod-security.kubernetes.io/enforce=privileged`,
  but an external policy controller may still reject the pods.
- Flannel of the inner cluster fails to establish the VXLAN network:
  make sure that the `vxlan` kernel module is loaded on the hosts, and that
  the network policy of the outer cluster allows UDP port 8472 between the
  node pods.
- A privileged pod of the inner cluster fails with
  `error mounting "sysfs" to rootfs at "/sys": ... operation not permitted`:
  make sure that the hosts provide the read-write sysfs instance at
  `/run/usernetes/sysfs` (see the requirements above), and recreate the node
  pods if the instance was mounted after them. For the `/sys` of privileged
  pods with `hostNetwork`, see the limitations above.
