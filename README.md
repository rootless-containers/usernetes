# Usernetes: Kubernetes without the root privileges

Usernetes aims to provide a reference distribution of Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

 - [Status](#status)
 - [Adoption](#adoption)
 - [How it works](#how-it-works)
 - [Requirements](#requirements)
 - [Restrictions](#restrictions)
 - [Install from binary](#install-from-binary)
 - [Install from source](#install-from-source)
 - [Quick start](#quick-start)
   - [Start Kubernetes with CRI-O](#start-kubernetes-with-cri-o)
   - [Start Kubernetes with containerd](#start-kubernetes-with-containerd)
   - [Use `kubectl`](#use-kubectl)
   - [Reset to factory defaults](#reset-to-factory-defaults)
 - [Run Usernetes in Docker](#run-usernetes-in-docker)
   - [Single node](#single-node)
   - [Multi node (Docker Compose)](#multi-node-docker-compose)
 - [Advanced guide](#advanced-guide)
   - [Expose netns ports to the host](#expose-netns-ports-to-the-host)
   - [Routing ping packets](#routing-ping-packets)
 - [License](#license)

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

Deployment shell scripts are in POC status. (It even lacks TLS setup - [#76](https://github.com/rootless-containers/usernetes/issues/76))

See [Adoption](#adoption) for Usernetes-based Kubernetes distributions with TLS support.

> **Note**
> [Usernetes no longer includes Docker (Moby) binaries since February 2020.](https://github.com/rootless-containers/usernetes/pull/126)
> To install Rootless Docker, see https://get.docker.com/rootless .
> See also https://docs.docker.com/engine/security/rootless/ for the further information.

## Adoption

We encourage other Kubernetes distributions to adopt Usernetes patches and tools.

Currently, the following distributions adopt Usernetes:
* [k3s](https://github.com/rancher/k3s)
* [Silverkube](https://github.com/podenv/silverkube)

## How it works

Usernetes executes Kubernetes and CRI runtimes without the root privileges by using unprivileged [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html), [`mount_namespaces(7)`](http://man7.org/linux/man-pages/man7/mount_namespaces.7.html), and [`network_namespaces(7)`](http://man7.org/linux/man-pages/man7/network_namespaces.7.html).

To set up NAT across the host and the network namespace without the root privilege, Usernetes uses a usermode network stack ([slirp4netns](https://github.com/rootless-containers/slirp4netns)).

No SETUID/SETCAP binary is needed. except [`newuidmap(1)`](http://man7.org/linux/man-pages/man1/newuidmap.1.html) and [`newgidmap(1)`](http://man7.org/linux/man-pages/man1/newgidmap.1.html), which are used for setting up [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html) with multiple sub-UIDs and sub-GIDs.

## Requirements

* `newuidmap` and `newgidmap` need to be installed on the host. These commands are provided by the `uidmap` package on most distros.

* `/etc/subuid` and `/etc/subgid` should contain more than 65536 sub-IDs. e.g. `penguin:231072:65536`. These files are automatically configured on most distros.

```console
$ id -u
1001
$ whoami
penguin
$ grep "^$(whoami):" /etc/subuid
penguin:231072:65536
$ grep "^$(whoami):" /etc/subgid
penguin:231072:65536
```

### Distribution-specific hint
#### Ubuntu
* No preparation is needed.
* overlayfs is enabled by default ([Ubuntu-specific kernel patch](https://kernel.ubuntu.com/git/ubuntu/ubuntu-bionic.git/commit/fs/overlayfs?id=3b7da90f28fe1ed4b79ef2d994c81efbc58f1144)).

#### Debian GNU/Linux
* Add `kernel.unprivileged_userns_clone=1` to `/etc/sysctl.conf` (or `/etc/sysctl.d`) and run `sudo sysctl -p`
* To use overlayfs (recommended), run `sudo modprobe overlay permit_mounts_in_userns=1` ([Debian-specific kernel patch, introduced in Debian 10](https://salsa.debian.org/kernel-team/linux/blob/283390e7feb21b47779b48e0c8eb0cc409d2c815/debian/patches/debian/overlayfs-permit-mounts-in-userns.patch)). Put the configuration to `/etc/modprobe.d` for persistence.

#### Arch Linux
* Add `kernel.unprivileged_userns_clone=1` to `/etc/sysctl.conf` (or `/etc/sysctl.d`) and run `sudo sysctl -p`

#### openSUSE
* `sudo modprobe ip_tables iptable_mangle iptable_nat iptable_filter` is required. (This is likely to be required on other distros as well)
* `sudo prlimit --nofile=:65536 --pid $$` is required for Kubernetes

#### Fedora 31 and later
* Run `sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"` and reboot.

#### Fedora 30
* No preparation is needed

#### RHEL/CentOS 8
* No preparation is needed

#### RHEL/CentOS 7
* Add `user.max_user_namespaces=28633` to `/etc/sysctl.conf` (or `/etc/sysctl.d`) and run `sudo sysctl -p`
* RHEL/CentOS 7.6 and older releases require [COPR package `vbatts/shadow-utils-newxidmap`](https://copr.fedorainfracloud.org/coprs/vbatts/shadow-utils-newxidmap/) to be installed.
* RHEL/CentOS 7.5 and older releases require running `sudo grubby --update-kernel=ALL --args="user_namespace.enable=1"` and reboot.

## Restrictions

Common:
* Following features are not supported:
  * Cgroups
  * Apparmor

CRI-O:
* Only `vfs` storage driver is supported.

containerd:
* Only `native` storage driver is supported. However, on Ubuntu and a few distros, `overlayfs` is also supported.

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

Binaries are genereted under `./bin` directory.

## Quick start

### Start Kubernetes with CRI-O

```console
$ ./run.sh default-crio
```

### Start Kubernetes with containerd

```console
$ ./run.sh default-containerd
```

### Use `kubectl`

```console
$ ./kubectl.sh get nodes
```

Or 

```console
$ ./rootlessctl.sh add-ports 127.0.0.1:8080:8080/tcp
$ export KUBECONFIG=$(pwd)/config/localhost.kubeconfig
$ kubectl get nodes
```

Or

```console
$ nsenter -U -n -t $(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid) \
  kubectl --kubeconfig=./config/localhost.kubeconfig get nodes
```

### Reset to factory defaults

```console
$ ./cleanup.sh
```

## Run Usernetes in Docker

All-in-one Docker image is available as [`rootlesscontainers/usernetes`](https://hub.docker.com/r/rootlesscontainers/usernetes) on Docker Hub.

To build the image manually:

```console
$ docker build -t rootlesscontainers/usernetes .
```

The image is by default based on Ubuntu.
To build a Fedora-based image (experimental), set `--build-arg BASEOS=fedora`.

### Single node

```console
$ docker run -d --name usernetes-node -p 127.0.0.1:8080:8080  -e U7S_ROOTLESSKIT_PORTS=0.0.0.0:8080:8080/tcp --privileged rootlesscontainers/usernetes default-docker
$ export KUBECONFIG=./config/localhost.kubeconfig
$ kubectl run -it --rm --image busybox foo
/ #
```

### Multi node (Docker Compose)

```console
$ docker-compose up -d
$ export KUBECONFIG=./config/localhost.kubeconfig
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

* `bin/slirp4netns`: [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-slirp4netns), see https://github.com/rootless-containers/slirp4netns
* `bin/socat`: [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-socat), see http://www.dest-unreach.org/socat/
* `bin/task`: [MIT License](docs/binary-release-license/LICENSE-task), see https://github.com/go-task/task
