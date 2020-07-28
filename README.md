# Usernetes: Kubernetes without the root privileges

Usernetes aims to provide a reference distribution of Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Included components](#included-components)
- [Adoption](#adoption)
- [How it works](#how-it-works)
- [Restrictions](#restrictions)
- [Requirements](#requirements)
  - [Distribution-specific hint](#distribution-specific-hint)
    - [Ubuntu](#ubuntu)
    - [Debian GNU/Linux](#debian-gnulinux)
    - [Arch Linux](#arch-linux)
    - [openSUSE](#opensuse)
    - [Fedora, RHEL/CentOS](#fedora-rhelcentos)
- [Quick start](#quick-start)
  - [Download](#download)
  - [Install](#install)
  - [Use `kubectl`](#use-kubectl)
  - [Uninstall](#uninstall)
- [Run Usernetes in Docker](#run-usernetes-in-docker)
  - [Single node](#single-node)
  - [Multi node (Docker Compose)](#multi-node-docker-compose)
- [Advanced guide](#advanced-guide)
  - [Enabling cgroups](#enabling-cgroups)
    - [Enable cgroup v2](#enable-cgroup-v2)
    - [Enable cpu controller](#enable-cpu-controller)
    - [Run Usernetes installer](#run-usernetes-installer)
  - [Expose netns ports to the host](#expose-netns-ports-to-the-host)
  - [Routing ping packets](#routing-ping-packets)
  - [IP addresses](#ip-addresses)
  - [Install Usernetes from source](#install-usernetes-from-source)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Included components

* Installer scripts
* Rootless Containers infrastructure ([RootlessKit](https://github.com/rootless-containers/rootlesskit), [slirp4netns](https://github.com/rootless-containers/slirp4netns), and [fuse-overlayfs](https://github.com/containers/fuse-overlayfs))
* Master components (`etcd`, `kube-apiserver`, ...)
* Node components (`kubelet` and `kube-proxy`)
* CRI runtimes
  * containerd (default)
  * CRI-O
* Multi-node CNI
  * Flannel (VXLAN)
* CoreDNS

Currently, Usernetes uses our patched version of `kubelet` and `kube-proxy`. We are proposing our patches to the Kubernetes upstream. See [#42](https://github.com/rootless-containers/usernetes/issues/42) for the current status.

Installer scripts are in POC status.

See [Adoption](#adoption) for Usernetes-based Kubernetes distributions.

> **Note**
>
> [Usernetes no longer includes Docker (Moby) binaries since February 2020.](https://github.com/rootless-containers/usernetes/pull/126)
>
> To install Rootless Docker, see https://get.docker.com/rootless .
>
> See also https://docs.docker.com/engine/security/rootless/ for the further information.

## Adoption

We encourage other Kubernetes distributions to adopt Usernetes patches and tools.

Currently, the following distributions adopt Usernetes:
* [k3s](https://github.com/rancher/k3s) (Recommended version: [v1.17.0+k3s1](https://github.com/rancher/k3s/releases/tag/v1.17.0%2Bk3s.1), newer version may have a bug: [rancher/k3s#1709](https://github.com/rancher/k3s/issues/1709))
* [Silverkube](https://github.com/podenv/silverkube)

## How it works

Usernetes executes Kubernetes and CRI runtimes without the root privileges by using unprivileged [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html), [`mount_namespaces(7)`](http://man7.org/linux/man-pages/man7/mount_namespaces.7.html), and [`network_namespaces(7)`](http://man7.org/linux/man-pages/man7/network_namespaces.7.html).

To set up NAT across the host and the network namespace without the root privilege, Usernetes uses a usermode network stack ([slirp4netns](https://github.com/rootless-containers/slirp4netns)).

No SETUID/SETCAP binary is needed, except [`newuidmap(1)`](http://man7.org/linux/man-pages/man1/newuidmap.1.html) and [`newgidmap(1)`](http://man7.org/linux/man-pages/man1/newgidmap.1.html), which are used for setting up [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html) with multiple sub-UIDs and sub-GIDs.

## Restrictions

* Usermode networking called [slirp4netns](https://github.com/rootless-containers/slirp4netns) is used instead of kernel-mode [vEth](http://man7.org/linux/man-pages/man4/veth.4.html) pairs.
* [fuse-overlayfs](https://github.com/containers/fuse-overlayfs) is used instead of kernel-mode overlayfs.
* Node ports are network-namespaced
* No support for cgroup v1. Resource limitations are ignored on cgroup v1 hosts. To enable support for cgroup (v2 only), see [Enabling cgroups](#enabling-cgroups).
* Apparmor is unsupported

## Requirements

* Kernel >= 4.18.

* Recent version of systemd. Known to work with systemd >= 242.

* `mount.fuse3` binary. Provided by `fuse3` package on most distros.

* `iptables` binary. Provided by `iptables` package on most distros.

* `newuidmap` and `newgidmap` binaries. Provided by `uidmap` package on most distros.

* `/etc/subuid` and `/etc/subgid` should contain more than 65536 sub-IDs. e.g. `exampleuser:231072:65536`. These files are automatically configured on most distros.

```console
$ id -u
1001
$ whoami
exampleuser
$ grep "^$(whoami):" /etc/subuid
exampleuser:231072:65536
$ grep "^$(whoami):" /etc/subgid
exampleuser:231072:65536
```

### Distribution-specific hint
#### Ubuntu
* No preparation is needed.

#### Debian GNU/Linux
* Add `kernel.unprivileged_userns_clone=1` to `/etc/sysctl.conf` (or `/etc/sysctl.d`) and run `sudo sysctl -p`

#### Arch Linux
* Add `kernel.unprivileged_userns_clone=1` to `/etc/sysctl.conf` (or `/etc/sysctl.d`) and run `sudo sysctl -p`

#### openSUSE
* `sudo modprobe ip_tables iptable_mangle iptable_nat iptable_filter` is required. (This is likely to be required on other distros as well)

#### Fedora, RHEL/CentOS
* Run `sudo dnf install -y iptables`.

## Quick start

### Download

Download the latest `usernetes-x86_64.tbz` from [Releases](https://github.com/rootless-containers/usernetes/releases).

```console
$ tar xjvf usernetes-x86_64.tbz
$ cd usernetes
```

### Install

`install.sh` installs Usernetes systemd units to `$HOME/.config/systemd/unit`.

To use containerd as the CRI runtime (default):
```console
$ ./install.sh --cri=containerd
[INFO] Base dir: /home/exampleuser/gopath/src/github.com/rootless-containers/usernetes
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-rootlesskit.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-etcd.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-etcd.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-master.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-apiserver.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-controller-manager.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-scheduler.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-node.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-containerd.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kubelet-containerd.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-proxy.service
[INFO] Starting u7s.target
+ systemctl --user -T enable u7s.target
Created symlink /home/exampleuser/.config/systemd/user/multi-user.target.wants/u7s.target → /home/exampleuser/.config/systemd/user/u7s.target.
+ systemctl --user -T start u7s.target
Enqueued anchor job 522 u7s.target/start.
Enqueued auxiliary job 538 u7s-rootlesskit.service/start.
Enqueued auxiliary job 542 u7s-kubelet-containerd.service/start.
Enqueued auxiliary job 541 u7s-containerd.service/start.
Enqueued auxiliary job 524 u7s-etcd.service/start.
Enqueued auxiliary job 546 u7s-kube-controller-manager.service/start.
Enqueued auxiliary job 523 u7s-etcd.target/start.
Enqueued auxiliary job 543 u7s-master.target/start.
Enqueued auxiliary job 544 u7s-kube-scheduler.service/start.
Enqueued auxiliary job 545 u7s-kube-apiserver.service/start.
Enqueued auxiliary job 539 u7s-node.target/start.
Enqueued auxiliary job 540 u7s-kube-proxy.service/start.
+ systemctl --user --no-pager status
● localhost
    State: running
...
[INFO] Hint: `sudo loginctl enable-linger` to start user services automatically on the system start up.
[INFO] Hint: To enable addons including CoreDNS, run: kubectl apply -f /home/exampleuser/gopath/src/github.com/rootless-containers/usernetes/manifests/*.yaml
[INFO] Hint: KUBECONFIG=/home/exampleuser/.config/usernetes/master/admin-localhost.kubeconfig
```

To enable CoreDNS:
```console
$ export KUBECONFIG="$HOME/.config/usernetes/master/admin-localhost.kubeconfig"
$ kubectl apply -f manifests/*.yaml
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.apps/coredns created
service/kube-dns created
```

To use CRI-O:
```console
$ ./install.sh --cri=crio
```

### Use `kubectl`

```console
$ export KUBECONFIG="$HOME/.config/usernetes/master/admin-localhost.kubeconfig"
$ kubectl get nodes -o wide
```

### Uninstall

```console
$ ./uninstall.sh
```

To remove data files:
```console
$ ./show-cleanup-command.sh
$ eval $(./show-cleanup-command.sh)
```

## Run Usernetes in Docker

All-in-one Docker image is available as [`rootlesscontainers/usernetes`](https://hub.docker.com/r/rootlesscontainers/usernetes) on Docker Hub.

To build the image manually:

```console
$ docker build -t rootlesscontainers/usernetes .
```

The image is based on Fedora.

### Single node

```console
$ docker run -td --name usernetes-node -p 127.0.0.1:6443:6443 --privileged rootlesscontainers/usernetes --cri=containerd
```

Wait until `docker ps` shows "healty" as the status of `usernetes-node` container.

```console
$ docker cp usernetes-node:/home/user/.config/usernetes/master/admin-localhost.kubeconfig docker.kubeconfig
$ export KUBECONFIG=./docker.kubeconfig
$ kubectl apply -f manifests/*.yaml
$ kubectl run -it --rm --image busybox foo
/ #
```

### Multi node (Docker Compose)

```console
$ make up
$ export KUBECONFIG=$HOME/.config/usernetes/docker-compose.kubeconfig
$ kubectl apply -f manifests/*.yaml
```

Flannel VXLAN `10.5.0.0/16` is configured by default.

```console
$ kubectl get nodes -o wide
NAME           STATUS   ROLES    AGE     VERSION           INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
967e81e90e1f   Ready    <none>   3m42s   v1.14-usernetes   10.0.101.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://Unknown
b2204f192e5c   Ready    <none>   3m42s   v1.14-usernetes   10.0.102.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   cri-o://1.14.0-dev
ba0133c68378   Ready    <none>   3m42s   v1.14-usernetes   10.0.103.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   containerd://1.2.0-168-gb3807c5d
$ kubectl run --replicas=3 --image=nginx:alpine nginx
$ kubectl get pods -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP          NODE           NOMINATED NODE   READINESS GATES
nginx-6b4b85b77b-7hqrk   1/1     Running   0          3s    10.5.13.3   b2204f192e5c   <none>           <none>
nginx-6b4b85b77b-8rknj   1/1     Running   0          3s    10.5.79.3   967e81e90e1f   <none>           <none>
nginx-6b4b85b77b-r466s   1/1     Running   0          3s    10.5.7.3    ba0133c68378   <none>           <none>
$ kubectl exec -it nginx-6b4b85b77b-7hqrk -- wget -O - http://10.5.79.3
Connecting to 10.5.79.3 (10.5.79.3:80)
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
$ kubectl exec -it nginx-6b4b85b77b-7hqrk -- wget -O - http://10.5.7.3
Connecting to 10.5.7.3 (10.5.7.3:80)
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

## Advanced guide

### Enabling cgroups

To enable cgroups (resource limits), the host needs to be running with cgroup v2.

If `/sys/fs/cgroup/cgroup.controllers` is present on your system, you are using v2, otherwise you are using v1.
As of 2020, Fedora is the only well-known Linux distributon that uses cgroup v2 by default. Fedora uses cgroup v2 by default since Fedora 31.

#### Enable cgroup v2
To enable cgroup v2, add `systemd.unified_cgroup_hierarchy=1` to the `GRUB_CMDLINE_LINUX` line in `/etc/default/grub` and run `sudo update-grub`.

If `grubby` command is available on your system, this step can be also accomplished with `sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"`.


#### Enable cpu controller
Typically, only `memory` and `pids` controllers are delegated to non-root users by default.
```console
$ cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
memory pids
```


To  allow delegation of all controllers, you need to change the systemd configuration as follows:

```console
# mkdir -p /etc/systemd/system/user@.service.d
# cat > /etc/systemd/system/user@.service.d/delegate.conf << EOF
[Service]
Delegate=cpu cpuset io memory pids
EOF
# systemctl daemon-reload
```

#### Run Usernetes installer

The installer script (`install.sh`) needs to be executed with `--cgroup-manager=systemd`.
```console
$ ./install.sh --cgroup-manager=systemd
```

Currently, `--cgroup-manager=systemd` is incompatible with `--cri=crio`.

### Expose netns ports to the host

As Usernetes runs in a network namespace (with [slirp4netns](https://github.com/rootless-containers/slirp4netns)),
you can't expose container ports to the host by just running `kubectl expose --type=NodePort`.

In addition, you need to expose Usernetes netns ports to the host:

```console
$ ./rootlessctl.sh add-ports 0.0.0.0:30080:30080/tcp
```

You can also manually expose Usernetes netns ports manually with `socat`:

```console
$ pid=$(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid)
$ socat -t -- TCP-LISTEN:30080,reuseaddr,fork EXEC:"nsenter -U -n -t $pid socat -t -- STDIN TCP4\:127.0.0.1\:30080"
```

### Routing ping packets

To route ping packets, you may need to set up `net.ipv4.ping_group_range` properly as the root.

```console
$ sudo sh -c "echo 0   2147483647  > /proc/sys/net/ipv4/ping_group_range"
```

### IP addresses

* 10.0.0.0/24: The CIDR for the Kubernetes ClusterIP services
  * 10.0.0.1: The kube-apiserver ClusterIP
  * 10.0.0.53: The CoreDNS ClusterIP

* 10.0.42.0/24: The default CIDR for the RootlessKit network namespace. Can be overridden with `install.sh --cidr=<CIDR>`. 
  * 10.0.42.2: The slirp4netns gateway
  * 10.0.42.3: The slirp4netns DNS
  * 10.0.42.100: The slirp4netns TAP device

* 10.0.100.0/24: The CIDR used instead of 10.0.42.0/24 in Docker Compose master
* 10.0.101.0/24: The CIDR used instead of 10.0.42.0/24 in Docker Compose containerd node
* 10.0.102.0/24: The CIDR used instead of 10.0.42.0/24 in Docker Compose CRI-O node

* 10.5.0.0/16: The CIDR for Flannel

* 10.88.0.0/16: The CIDR for single-node CNI

### Install Usernetes from source

Docker 17.05+ is required for building Usernetes from the source.
Docker 18.09+ with `DOCKER_BUILDKIT=1` is recommended.

```console
$ make
```

Binaries are generated under `./bin` directory.

## License

Usernetes is licensed under the terms of  [Apache License Version 2.0](LICENSE).

The binary releases of Usernetes contain files that are licensed under the terms of different licenses:

* `bin/crun`:  [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-crun), see https://github.com/containers/crun
* `bin/fuse-overlayfs`:  [GNU GENERAL PUBLIC LICENSE Version 3](docs/binary-release-license/LICENSE-fuse-overlayfs), see https://github.com/containers/fuse-overlayfs
* `bin/slirp4netns`: [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-slirp4netns), see https://github.com/rootless-containers/slirp4netns
* `bin/{cfssl,cfssljson}`: [2-Clause BSD License](docs/binary-release-license/LICENSE-cfssl), see https://github.com/cloudflare/cfssl
