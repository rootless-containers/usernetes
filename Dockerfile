# this dockerfile can be translated to `docker/dockerfile:1-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile  | DOCKER_BUILDKIT=1 docker build  -f -  .

### Version definitions
# use ./hack/show-latest-commits.sh to get the latest commits

# 2020-03-05T09:59:12Z
ARG ROOTLESSKIT_COMMIT=b4d749c9884d3264cb350fcde2f5bc4ab96af871
# 2019-12-18T03:10:18Z
ARG SLIRP4NETNS_COMMIT=a8414d1d1629f6f7a93b60b55e183a93d10d9a1c
# 2020-03-05T00:32:45Z
ARG RUNC_COMMIT=6503438fd6b0415bc146403b30b8a248b3346f52
# 2020-03-01T05:55:11Z
ARG CONTAINERD_COMMIT=ca66f3dd5d917694797a377b8ab9b8fb603b089b
# 2020-02-20T08:27:20Z
ARG CONTAINERD_FUSE_OVERLAYFS_COMMIT=bb896865146c4c0fdb06933f7fddb5603019e0ed
# 2020-03-05T09:10:28Z
ARG CRIO_COMMIT=d0665fd81f4a651d6b4c6a480d2b598b18c93f4f
# 2020-03-05T10:58:50Z
ARG KUBERNETES_COMMIT=67c6767b7da983034be04a31575261890186338a

# Version definitions (cont.)
ARG CONMON_RELEASE=v2.0.11
ARG CRUN_RELEASE=0.13
ARG FUSE_OVERLAYFS_RELEASE=v0.7.7
# Kube's build script requires KUBE_GIT_VERSION to be set to a semver string
ARG KUBE_GIT_VERSION=v1.18.0-usernetes
ARG SOCAT_RELEASE=1.7.3.4
ARG CNI_PLUGINS_RELEASE=v0.8.5
ARG FLANNEL_RELEASE=v0.11.0
ARG ETCD_RELEASE=v3.4.4

### Common base images (common-*)
FROM alpine:3.11 AS common-alpine
RUN apk add -q --no-cache git build-base autoconf automake libtool

FROM golang:1.13-alpine AS common-golang-alpine
RUN apk add -q --no-cache git

FROM common-golang-alpine AS common-golang-alpine-heavy
RUN apk -q --no-cache add bash build-base linux-headers libseccomp-dev

### RootlessKit (rootlesskit-build)
FROM common-golang-alpine AS rootlesskit-build
RUN git clone -q https://github.com/rootless-containers/rootlesskit.git /go/src/github.com/rootless-containers/rootlesskit
WORKDIR /go/src/github.com/rootless-containers/rootlesskit
ARG ROOTLESSKIT_COMMIT
RUN git pull && git checkout ${ROOTLESSKIT_COMMIT}
ENV CGO_ENABLED=0
ENV GO111MODULE=off
RUN mkdir /out && \
  go build -o /out/rootlesskit github.com/rootless-containers/rootlesskit/cmd/rootlesskit && \
  go build -o /out/rootlessctl github.com/rootless-containers/rootlesskit/cmd/rootlessctl

#### slirp4netns (slirp4netns-build)
FROM common-alpine AS slirp4netns-build
RUN apk add -q --no-cache linux-headers glib-dev glib-static libcap-static libcap-dev libseccomp-dev
RUN git clone -q https://github.com/rootless-containers/slirp4netns.git /slirp4netns
WORKDIR /slirp4netns
ARG SLIRP4NETNS_COMMIT
RUN git pull && git checkout ${SLIRP4NETNS_COMMIT}
RUN ./autogen.sh && ./configure -q LDFLAGS="-static" && make --quiet && \
  mkdir /out && cp slirp4netns /out

### fuse-overlayfs (fuse-overlayfs-build)
# Based on https://github.com/containers/fuse-overlayfs/blob/v0.7.6/Dockerfile.static.ubuntu .
# We can't use Alpine here because Alpine does not provide an apk package for libfuse3.a .
FROM debian:10 AS fuse-overlayfs-build
RUN apt-get update && \
  apt-get install -q --no-install-recommends -y \
  git ca-certificates libc6-dev gcc make automake autoconf pkgconf libfuse3-dev file
RUN git clone https://github.com/containers/fuse-overlayfs
WORKDIR fuse-overlayfs
ARG FUSE_OVERLAYFS_RELEASE
RUN git pull && git checkout ${FUSE_OVERLAYFS_RELEASE}
RUN  ./autogen.sh && \
  LIBS="-ldl" LDFLAGS="-static" ./configure -q && \
  make --quiet && mkdir /out && cp fuse-overlayfs /out && \
  file /out/fuse-overlayfs | grep "statically linked"

### crun (crun-build)
FROM busybox AS crun-build
ARG CRUN_RELEASE
ADD https://github.com/containers/crun/releases/download/${CRUN_RELEASE}/crun-${CRUN_RELEASE}-static-x86_64 /out/crun
RUN chmod +x /out/crun

### containerd (containerd-build)
FROM common-golang-alpine-heavy AS containerd-build
RUN git clone https://github.com/containerd/containerd.git /go/src/github.com/containerd/containerd
WORKDIR /go/src/github.com/containerd/containerd
ARG CONTAINERD_COMMIT
RUN git pull && git checkout ${CONTAINERD_COMMIT}
ENV GO111MODULE=off
RUN make --quiet EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS='-extldflags "-fno-PIC -static"' BUILDTAGS="netgo osusergo static_build no_devmapper no_btrfs no_aufs no_zfs" \
  bin/containerd bin/containerd-shim-runc-v2 bin/ctr && \
  mkdir /out && cp bin/containerd bin/containerd-shim-runc-v2 bin/ctr /out

### containerd-fuse-overlayfs (containerd-fuse-overlayfs-build)
FROM common-golang-alpine AS containerd-fuse-overlayfs-build
RUN git clone -q https://github.com/AkihiroSuda/containerd-fuse-overlayfs.git /go/src/github.com/AkihiroSuda/containerd-fuse-overlayfs
WORKDIR /go/src/github.com/AkihiroSuda/containerd-fuse-overlayfs
ARG CONTAINERD_FUSE_OVERLAYFS_COMMIT
RUN git pull && git checkout ${CONTAINERD_FUSE_OVERLAYFS_COMMIT}
ENV CGO_ENABLED=0
ENV GO111MODULE=off
RUN mkdir /out && \
  go build -o /out/containerd-fuse-overlayfs-grpc github.com/AkihiroSuda/containerd-fuse-overlayfs/cmd/containerd-fuse-overlayfs-grpc

### CRI-O (crio-build)
FROM common-golang-alpine-heavy AS crio-build
RUN git clone -q https://github.com/cri-o/cri-o.git /go/src/github.com/cri-o/cri-o
WORKDIR /go/src/github.com/cri-o/cri-o
ARG CRIO_COMMIT
RUN git pull && git checkout ${CRIO_COMMIT}
ENV GO111MODULE=off
RUN EXTRA_LDFLAGS='-linkmode external -extldflags "-static"' make binaries && \
  mkdir /out && cp bin/crio bin/crio-status bin/pinns /out

### conmon (conmon-build)
FROM common-golang-alpine-heavy AS conmon-build
RUN apk add -q --no-cache glib-dev glib-static
RUN git clone https://github.com/containers/conmon.git /go/src/github.com/containers/conmon
WORKDIR /go/src/github.com/containers/conmon
ARG CONMON_RELEASE
RUN git pull && git checkout ${CONMON_RELEASE}
RUN make static && mkdir /out && cp bin/conmon /out

### CNI Plugins (cniplugins-build)
FROM busybox AS cniplugins-build
ARG CNI_PLUGINS_RELEASE
RUN mkdir -p /out/cni && \
 wget -q -O - https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_RELEASE}/cni-plugins-linux-amd64-${CNI_PLUGINS_RELEASE}.tgz | tar xz -C /out/cni

### Kubernetes (k8s-build)
FROM common-golang-alpine-heavy AS k8s-build
RUN apk add -q --no-cache rsync
RUN git clone -q https://github.com/kubernetes/kubernetes.git /kubernetes
WORKDIR /kubernetes
ARG KUBERNETES_COMMIT
RUN git pull && git checkout ${KUBERNETES_COMMIT}
COPY ./src/patches/kubernetes /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary
ARG KUBE_GIT_VERSION
ENV KUBE_GIT_VERSION=${KUBE_GIT_VERSION}
ENV GO111MODULE=off
# runopt = --mount=type=cache,id=u7s-k8s-build-cache,target=/root
RUN KUBE_STATIC_OVERRIDES=kubelet \
  make --quiet kube-apiserver kube-controller-manager kube-proxy kube-scheduler kubectl kubelet && \
  mkdir /out && cp _output/bin/kube* /out

### socat (socat-build)
FROM common-alpine AS socat-build
ARG SOCAT_RELEASE
RUN wget -q -O - http://www.dest-unreach.org/socat/download/socat-${SOCAT_RELEASE}.tar.gz | tar xz -C /
WORKDIR /socat-${SOCAT_RELEASE}
RUN LIBS="-static" ./configure -q && make --quiet socat && strip socat && \
  mkdir -p /out && cp -f socat /out

#### flannel (flannel-build)
FROM busybox AS flannel-build
ARG FLANNEL_RELEASE
RUN mkdir -p /out && \
  wget -q -O /out/flanneld https://github.com/coreos/flannel/releases/download/${FLANNEL_RELEASE}/flanneld-amd64 && \
  chmod +x /out/flanneld

#### etcd (etcd-build)
FROM busybox AS etcd-build
ARG ETCD_RELEASE
RUN mkdir /tmp-etcd out && \
  wget -q -O - https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz | tar xz -C /tmp-etcd && \
  cp /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcd /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcdctl /out

### Binaries (bin-main)
FROM scratch AS bin-main
COPY --from=rootlesskit-build /out/* /
COPY --from=slirp4netns-build /out/* /
COPY --from=fuse-overlayfs-build /out/* /
COPY --from=crun-build /out/* /
COPY --from=containerd-build /out/* /
COPY --from=containerd-fuse-overlayfs-build /out/* /
COPY --from=crio-build /out/* /
COPY --from=conmon-build /out/* /
# can't use wildcard here: https://github.com/rootless-containers/usernetes/issues/78
COPY --from=cniplugins-build /out/cni /cni
COPY --from=k8s-build /out/* /
COPY --from=socat-build /out/* /
COPY --from=flannel-build /out/* /
COPY --from=etcd-build /out/* /

#### Test (test-main)
FROM fedora:31 AS test-main
ADD https://raw.githubusercontent.com/AkihiroSuda/containerized-systemd/6ced78a9df65c13399ef1ce41c0bedc194d7cff6/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && \
# As of Feb 2020, Fedora has wrong permission bits on newuidmap and newgidmap.
  chmod +s /usr/bin/newuidmap /usr/bin/newgidmap && \
  dnf install -q -y findutils fuse3 git iproute iptables hostname procps-ng \
# systemd-container: for machinectl
  systemd-container && \
  useradd --create-home --home-dir /home/user --uid 1000 -G systemd-journal user && \
  mkdir -p /home/user/.local
COPY --from=bin-main / /home/user/usernetes-bin
COPY . /home/user/usernetes
RUN rm -rf /home/user/usernetes/bin && \
  mv /home/user/usernetes-bin /home/user/usernetes/bin && \
  chown -R user:user /home/user && \
  rm -rf /tmp/*
VOLUME /home/user/.local
ENTRYPOINT ["/docker-entrypoint.sh", "machinectl", "shell", "user@", "/home/user/usernetes/boot/docker-2ndboot.sh"]
