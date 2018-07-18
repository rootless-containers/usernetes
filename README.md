# Usernetes: Moby (aka Docker) & Kubernetes, without the root privileges

Usernetes aims to provide a binary distribution of Moby (aka Docker) and Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

## Status

* Moby (`dockerd`): Almost usable (except Swarm-mode)
* Kubernetes: Early POC with a single node. Don't use yet!

We also plan to support containerd and CRI-O as CRI runtimes.

## Requirements

* `newuidmap` and `newgidmap` need to be installed on the host. These commands are provided by the `uidmap` package on most distros.

* `/etc/subuid` and `/etc/subgid` should contain >= 65536 sub-IDs. e.g. `penguin:231072:65536`.

```console
$ id -u
1001
$ whoami
penguin
$ grep ^$(whoami): /etc/subuid
penguin:231072:65536
$ grep ^$(whoami): /etc/subgid
penguin:231072:65536
```

* Some distros such as Debian (excluding Ubuntu) and Arch Linux require `echo 1 > /proc/sys/kernel/unprivileged_userns_clone`.

## Restrictions

Moby (`dockerd`):
* Only `vfs` graphdriver is supported. However, on [Ubuntu](http://kernel.ubuntu.com/git/ubuntu/ubuntu-artful.git/commit/fs/overlayfs?h=Ubuntu-4.13.0-25.29&id=0a414bdc3d01f3b61ed86cfe3ce8b63a
9240eba7) and a few distros, `overlay2` and `overlay` are also supported. [Starting with Linux 4.18](https://www.phoronix.com/scan.php?page=news_item&px=Linux-4.18-FUSE), we will be also able
 to implement FUSE snapshotters.
* Cgroups (including `docker top`) and AppArmor are disabled at the moment. (FIXME: we could enable Cgroups if configured on the host)
* Checkpoint is not supported at the moment.
* Running rootless `dockerd` in rootless/rootful `dockerd` is also possible, but not fully tested.

Kubernetes:
* `kubectl run -it` not working? (`kubectl run` works)

## Quickstart

### Installation

To be documented

* AkihiroSuda/docker@159a21ae645e13fbe98ed363c11d2d0d714d60bb
  * `make binary`
  * Install `bundles/binary-daemon/*` to `~/bin`

* AkihiroSuda/kubernetes@99bd84d4b4bbf16470fbf66e2305e15fe63b85be
  * `bazel build cmd/hyperkube`
  * Install `bazel-bin/cmd/hyperkube/linux_amd64_stripped/hyperkube` to `~/bin`

* https://github.com/go-task/task

### Usage

Please refer to [`Taskfile.yml`](Taskfile.yml).
