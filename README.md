# Usernetes: Moby (aka Docker) & Kubernetes, without the root privileges

Usernetes aims to provide a binary distribution of Moby (aka Docker) and Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

## Status

* Moby (`dockerd`): Almost usable (except Swarm-mode)
* Kubernetes: Early POC with a single node

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
* Only `vfs` graphdriver is supported. However, on [Ubuntu](http://kernel.ubuntu.com/git/ubuntu/ubuntu-artful.git/commit/fs/overlayfs?h=Ubuntu-4.13.0-25.29&id=0a414bdc3d01f3b61ed86cfe3ce8b63a9240eba7) and a few distros, `overlay2` and `overlay` are also supported. [Starting with Linux 4.18](https://www.phoronix.com/scan.php?page=news_item&px=Linux-4.18-FUSE), we will be also able
 to implement FUSE snapshotters.
* Cgroups (including `docker top`) and AppArmor are disabled at the moment. (FIXME: we could enable Cgroups if configured on the host)
* Checkpoint is not supported at the moment.
* Running rootless `dockerd` in rootless/rootful `dockerd` is also possible, but not fully tested.

Kubernetes:
* (Almost untested)

## Install from binary

Download the latest `usernetes-x86_64.tbz` from [Releases](https://github.com/rootless-containers/usernetes/releases).

```console
$ tar xjvf usernetes-x86_64.tbz
$ cd usernetes
```

## Install from source

```console
$ go get github.com/go-task/task/cmd/task
$ task -d build
```

## Quick start

### Start the daemons

```console
$ ./run.sh
```

If you don't need Kubernetes:
```console
$ ./run.sh dockerd
```

### Use `docker`

```console
$ docker -H unix:///run/user/1001/docker.sock info
```

Or

```console
$ ./dockercli.sh info
```

### Use `kubectl`

```console
$ nsenter -U -n -t $(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid) hyperkube kubectl --kubeconfig=./localhost.kubeconfig get nodes
```

Or

```console
$ ./kubectl.sh get nodes
```

### Reset to factory defaults

```console
$ ./cleanup.sh
```

## License

Usernetes is licensed under the terms of  [Apache License Version 2.0](LICENSE).

The binary releases of Usernetes contain files that are licensed under the terms of different licenses:

* `bin/slirp4netns`: [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-slirp4netns), see https://github.com/rootless-containers/slirp4netns
* `bin/task`: [MIT License](docs/binary-release-license/LICENSE-task), see https://github.com/go-task/task
