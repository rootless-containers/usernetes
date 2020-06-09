# Usernetes: Kubernetes without the root privileges

Usernetes aims to provide a reference distribution of Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Status](#status)
- [Adoption](#adoption)
- [How it works](#how-it-works)
- [Requirements](#requirements)
  - [Distribution-specific hint](#distribution-specific-hint)
    - [Ubuntu](#ubuntu)
    - [Debian GNU/Linux](#debian-gnulinux)
    - [Arch Linux](#arch-linux)
    - [openSUSE](#opensuse)
    - [Fedora 31 and later](#fedora-31-and-later)
    - [Fedora 30](#fedora-30)
    - [RHEL/CentOS 8](#rhelcentos-8)
    - [RHEL/CentOS 7](#rhelcentos-7)
- [Restrictions](#restrictions)
- [Install from binary](#install-from-binary)
- [Install from source](#install-from-source)
- [Quick start](#quick-start)
  - [Install](#install)
  - [Use `kubectl`](#use-kubectl)
  - [Uninstall](#uninstall)
- [Run Usernetes in Docker](#run-usernetes-in-docker)
  - [Single node](#single-node)
  - [Multi node (Docker Compose)](#multi-node-docker-compose)
- [Advanced guide](#advanced-guide)
  - [Expose netns ports to the host](#expose-netns-ports-to-the-host)
  - [Routing ping packets](#routing-ping-packets)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Status

* [X] master components (etcd, kube-apiserver, ...)
* [X] kubelet
* [X] CRI runtimes
  * [X] CRI-O
  * [X] containerd
* [ ] Cgroup
* [X] Multi-node CNI
  * [X] Flannel (VXLAN)

Currently, Usernetes uses our patched version of Kubernetes. See [`./src/patches`](./src/patches).
We are proposing our patches to the Kubernetes upstream. See [#42](https://github.com/rootless-containers/usernetes/issues/42) for the current status.

Deployment shell scripts are in POC status.

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
* [k3s](https://github.com/rancher/k3s)
* [Silverkube](https://github.com/podenv/silverkube)

## How it works

Usernetes executes Kubernetes and CRI runtimes without the root privileges by using unprivileged [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html), [`mount_namespaces(7)`](http://man7.org/linux/man-pages/man7/mount_namespaces.7.html), and [`network_namespaces(7)`](http://man7.org/linux/man-pages/man7/network_namespaces.7.html).

To set up NAT across the host and the network namespace without the root privilege, Usernetes uses a usermode network stack ([slirp4netns](https://github.com/rootless-containers/slirp4netns)).

No SETUID/SETCAP binary is needed, except [`newuidmap(1)`](http://man7.org/linux/man-pages/man1/newuidmap.1.html) and [`newgidmap(1)`](http://man7.org/linux/man-pages/man1/newgidmap.1.html), which are used for setting up [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html) with multiple sub-UIDs and sub-GIDs.

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

#### Fedora
* Run `sudo dnf install -y iptables`.
* If doesn't work on Fedora >= 31, try `sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"` and reboot.

#### RHEL/CentOS 8
* Run `sudo dnf install -y iptables`.

#### RHEL/CentOS 7
* Unsupported since February 2020. [Usernetes v20200126.0 (January 26, 2020)](https://github.com/rootless-containers/usernetes/tree/v20200126.0#rhelcentos-7) should work.

## Restrictions

* [slirp4netns](https://github.com/rootless-containers/slirp4netns) is used instead of [vEth](http://man7.org/linux/man-pages/man4/veth.4.html) pairs.
* [fuse-overlayfs](https://github.com/containers/fuse-overlayfs) is used instead of overlayfs.
* Following features are not supported:
  * Cgroups
  * Apparmor

## Install from binary

Download the latest `usernetes-x86_64.tbz` from [Releases](https://github.com/rootless-containers/usernetes/releases).

```console
$ tar xjvf usernetes-x86_64.tbz
$ cd usernetes
```

## Install from source

Docker 17.05+ is required for building Usernetes from the source.
Docker 18.09+ with `DOCKER_BUILDKIT=1` is recommended.

```console
$ make
```

Binaries are generated under `./bin` directory.

## Quick start

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
$ kubectl run -it --rm --image busybox foo
/ #
```

### Multi node (Docker Compose)

```console
$ make up
$ export KUBECONFIG=$HOME/.config/usernetes/docker-compose.kubeconfig
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

### Expose netns ports to the host

As Usernetes runs in a network namespace (with [slirp4netns](https://github.com/rootless-containers/slirp4netns)),
you can't expose container ports to the host by just running `kubectl expose --type=NodePort`.

In addition, you need to expose Usernetes netns ports to the host:

```console
$ ./rootlessctl.sh add-ports 0.0.0.0:8080:80/tcp
```

You can also manually expose Usernetes netns ports manually with `socat`:

```console
$ pid=$(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid)
$ socat -t -- TCP-LISTEN:8080,reuseaddr,fork EXEC:"nsenter -U -n -t $pid socat -t -- STDIN TCP4\:127.0.0.1\:80"
```

### Routing ping packets

To route ping packets, you need to set up `net.ipv4.ping_group_range` properly as the root.

```console
$ sudo sh -c "echo 0   2147483647  > /proc/sys/net/ipv4/ping_group_range"
```

## License

Usernetes is licensed under the terms of  [Apache License Version 2.0](LICENSE).

The binary releases of Usernetes contain files that are licensed under the terms of different licenses:

* `bin/crun`:  [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-crun), see https://github.com/containers/crun
* `bin/fuse-overlayfs`:  [GNU GENERAL PUBLIC LICENSE Version 3](docs/binary-release-license/LICENSE-fuse-overlayfs), see https://github.com/containers/fuse-overlayfs
* `bin/slirp4netns`: [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-slirp4netns), see https://github.com/rootless-containers/slirp4netns
