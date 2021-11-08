# this dockerfile can be translated to `docker/dockerfile:1-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile  | DOCKER_BUILDKIT=1 docker build  -f -  .

### Version definitions
# use ./hack/show-latest-commits.sh to get the latest commits

# 2021-11-08T06:45:24Z
ARG ROOTLESSKIT_COMMIT=9c9440ee0de17810a850f12a94eea6eee279f956
# 2021-11-04T22:26:49Z
ARG CONTAINERD_COMMIT=d418660889b94ec51e5b12e1b593f92fb4bba560
# 2021-11-04T12:08:33Z
ARG CRIO_COMMIT=394333403c4e5597ee20247f0f2762b7a9c78a4d

ARG KUBE_NODE_COMMIT=v1.23.0-alpha.4

# Version definitions (cont.)
ARG SLIRP4NETNS_RELEASE=v1.1.12
ARG CONMON_RELEASE=2.0.30
ARG CRUN_RELEASE=1.3
ARG FUSE_OVERLAYFS_RELEASE=v1.7.1
ARG CONTAINERD_FUSE_OVERLAYFS_RELEASE=1.0.3
ARG KUBE_MASTER_RELEASE=v1.23.0-alpha.4
# Kube's build script requires KUBE_GIT_VERSION to be set to a semver string
ARG KUBE_GIT_VERSION=v1.23.0-usernetes
ARG CNI_PLUGINS_RELEASE=v1.0.1
ARG FLANNEL_CNI_PLUGIN_RELEASE=v1.0.0
ARG FLANNEL_RELEASE=v0.15.0
ARG ETCD_RELEASE=v3.5.1
ARG CFSSL_RELEASE=1.6.1

ARG ALPINE_RELEASE=3.14
ARG GO_RELEASE=1.17
ARG FEDORA_RELEASE=35

### Common base images (common-*)
FROM alpine:${ALPINE_RELEASE} AS common-alpine
RUN apk add -q --no-cache git build-base autoconf automake libtool

FROM golang:${GO_RELEASE}-alpine AS common-golang-alpine
RUN apk add -q --no-cache git

FROM common-golang-alpine AS common-golang-alpine-heavy
RUN apk -q --no-cache add bash build-base linux-headers libseccomp-dev libseccomp-static

### RootlessKit (rootlesskit-build)
FROM common-golang-alpine AS rootlesskit-build
RUN git clone -q https://github.com/rootless-containers/rootlesskit.git /go/src/github.com/rootless-containers/rootlesskit
WORKDIR /go/src/github.com/rootless-containers/rootlesskit
ARG ROOTLESSKIT_COMMIT
RUN git pull && git checkout ${ROOTLESSKIT_COMMIT}
ENV CGO_ENABLED=0
RUN mkdir /out && \
  go build -o /out/rootlesskit github.com/rootless-containers/rootlesskit/cmd/rootlesskit && \
  go build -o /out/rootlessctl github.com/rootless-containers/rootlesskit/cmd/rootlessctl

#### slirp4netns (slirp4netns-build)
FROM busybox AS slirp4netns-build
ARG SLIRP4NETNS_RELEASE
ADD https://github.com/rootless-containers/slirp4netns/releases/download/${SLIRP4NETNS_RELEASE}/slirp4netns-x86_64 /out/slirp4netns
RUN chmod +x /out/slirp4netns

### fuse-overlayfs (fuse-overlayfs-build)
FROM busybox AS fuse-overlayfs-build
ARG FUSE_OVERLAYFS_RELEASE
ADD https://github.com/containers/fuse-overlayfs/releases/download/${FUSE_OVERLAYFS_RELEASE}/fuse-overlayfs-x86_64 /out/fuse-overlayfs
RUN chmod +x /out/fuse-overlayfs

### containerd-fuse-overlayfs (containerd-fuse-overlayfs-build)
FROM busybox AS containerd-fuse-overlayfs-build
ARG CONTAINERD_FUSE_OVERLAYFS_RELEASE
RUN mkdir -p /out && \
 wget -q -O - https://github.com/containerd/fuse-overlayfs-snapshotter/releases/download/v${CONTAINERD_FUSE_OVERLAYFS_RELEASE}/containerd-fuse-overlayfs-${CONTAINERD_FUSE_OVERLAYFS_RELEASE}-linux-amd64.tar.gz | tar xz -C /out

### crun (crun-build)
FROM busybox AS crun-build
ARG CRUN_RELEASE
ADD https://github.com/containers/crun/releases/download/${CRUN_RELEASE}/crun-${CRUN_RELEASE}-linux-amd64 /out/crun
RUN chmod +x /out/crun

### containerd (containerd-build)
FROM common-golang-alpine-heavy AS containerd-build
RUN git clone https://github.com/containerd/containerd.git /go/src/github.com/containerd/containerd
WORKDIR /go/src/github.com/containerd/containerd
ARG CONTAINERD_COMMIT
RUN git pull && git checkout ${CONTAINERD_COMMIT}
ENV CGO_ENABLED=0
RUN make --quiet EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS='-linkmode external -extldflags "-fno-PIC -static"' BUILDTAGS="netgo osusergo static_build no_devmapper no_btrfs no_aufs no_zfs" \
  bin/containerd bin/containerd-shim-runc-v2 bin/ctr && \
  mkdir /out && cp bin/containerd bin/containerd-shim-runc-v2 bin/ctr /out

### CRI-O (crio-build)
FROM common-golang-alpine-heavy AS crio-build
RUN apk add -q --no-cache gpgme gpgme-dev
RUN git clone -q https://github.com/cri-o/cri-o.git /go/src/github.com/cri-o/cri-o
WORKDIR /go/src/github.com/cri-o/cri-o
ARG CRIO_COMMIT
RUN git pull && git checkout ${CRIO_COMMIT}
RUN EXTRA_LDFLAGS='-linkmode external -extldflags "-static"' make binaries && \
  mkdir /out && cp bin/crio bin/crio-status bin/pinns /out

### conmon (conmon-build)
FROM common-golang-alpine-heavy AS conmon-build
RUN apk add -q --no-cache glib-dev glib-static libseccomp-dev libseccomp-static
RUN git clone -q https://github.com/containers/conmon.git /go/src/github.com/containers/conmon
WORKDIR /go/src/github.com/containers/conmon
ARG CONMON_COMMIT
RUN git pull && git checkout ${CONMON_COMMIT}
RUN make PKG_CONFIG='pkg-config --static' CFLAGS='-static' LDFLAGS='-s -w -static' && \
  mkdir /out && cp bin/conmon /out

### CNI Plugins (cniplugins-build)
FROM busybox AS cniplugins-build
ARG CNI_PLUGINS_RELEASE
RUN mkdir -p /out/cni && \
 wget -q -O - https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_RELEASE}/cni-plugins-linux-amd64-${CNI_PLUGINS_RELEASE}.tgz | tar xz -C /out/cni && \
 cd /out/cni && ls | egrep -vx "(host-local|loopback|bridge|portmap)" | xargs rm -f
ARG FLANNEL_CNI_PLUGIN_RELEASE
RUN wget -q -O /out/cni/flannel https://github.com/flannel-io/cni-plugin/releases/download/${FLANNEL_CNI_PLUGIN_RELEASE}/flannel-amd64 && \
  chmod +x /out/cni/flannel

### Kubernetes master (kube-master-build)
FROM busybox AS kube-master-build
ARG KUBE_MASTER_RELEASE
RUN mkdir /out && \
  wget -q -O - https://dl.k8s.io/${KUBE_MASTER_RELEASE}/kubernetes-server-linux-amd64.tar.gz | tar xz -C / && \
  cd /kubernetes/server/bin && \
  cp kube-apiserver kube-controller-manager kube-scheduler kubectl /out

### Kubernetes node (kube-node-build)
FROM common-golang-alpine-heavy AS kube-node-build
RUN apk add -q --no-cache rsync
RUN git clone -q https://github.com/kubernetes/kubernetes.git /kubernetes
WORKDIR /kubernetes
ARG KUBE_NODE_COMMIT
RUN git pull && git checkout ${KUBE_NODE_COMMIT}
ARG KUBE_GIT_VERSION
# runopt = --mount=type=cache,id=u7s-k8s-build-cache,target=/root
RUN KUBE_STATIC_OVERRIDES=kubelet GOFLAGS=-tags=dockerless \
  make --quiet kube-proxy kubelet && \
  mkdir /out && cp _output/bin/kube* /out

#### flannel (flannel-build)
# TODO: use upstream binary when https://github.com/coreos/flannel/issues/1365 gets resolved
FROM common-golang-alpine-heavy AS flannel-build
RUN git clone -q https://github.com/coreos/flannel.git /go/src/github.com/coreos/flannel
WORKDIR /go/src/github.com/coreos/flannel
ARG FLANNEL_RELEASE
RUN git pull && git checkout ${FLANNEL_RELEASE}
ENV CGO_ENABLED=0
RUN make dist/flanneld && \
  mkdir /out && cp dist/flanneld /out

#### etcd (etcd-build)
FROM busybox AS etcd-build
ARG ETCD_RELEASE
RUN mkdir /tmp-etcd /out && \
  wget -q -O - https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz | tar xz -C /tmp-etcd && \
  cp /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcd /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcdctl /out

#### cfssl (cfssl-build)
FROM busybox AS cfssl-build
ARG CFSSL_RELEASE
RUN mkdir -p /out && \
  wget -q -O /out/cfssl https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_RELEASE}/cfssl_${CFSSL_RELEASE}_linux_amd64 && \
  chmod +x /out/cfssl && \
  wget -q -O /out/cfssljson https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_RELEASE}/cfssljson_${CFSSL_RELEASE}_linux_amd64 && \
  chmod +x /out/cfssljson

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
COPY --from=kube-master-build /out/* /
COPY --from=kube-node-build /out/* /
COPY --from=flannel-build /out/* /
COPY --from=etcd-build /out/* /
COPY --from=cfssl-build /out/* /

#### Test (test-main)
FROM fedora:${FEDORA_RELEASE} AS test-main
ADD https://raw.githubusercontent.com/AkihiroSuda/containerized-systemd/6ced78a9df65c13399ef1ce41c0bedc194d7cff6/docker-entrypoint.sh /docker-entrypoint.sh
COPY hack/etc_systemd_system_user@.service.d_delegate.conf /etc/systemd/system/user@.service.d/delegate.conf
RUN chmod +x /docker-entrypoint.sh && \
# As of Feb 2020, Fedora has wrong permission bits on newuidmap and newgidmap.
  chmod +s /usr/bin/newuidmap /usr/bin/newgidmap && \
  dnf install -q -y conntrack findutils fuse3 git iproute iptables hostname procps-ng time which \
# systemd-container: for machinectl
  systemd-container && \
  useradd --create-home --home-dir /home/user --uid 1000 -G systemd-journal user && \
  mkdir -p /home/user/.local /home/user/.config/usernetes && \
  chown -R user:user /home/user && \
  rm -rf /tmp/*
COPY --chown=user:user . /home/user/usernetes
COPY --from=bin-main --chown=user:user / /home/user/usernetes/bin
RUN ln -sf /home/user/usernetes/boot/docker-unsudo.sh /usr/local/bin/unsudo
VOLUME /home/user/.local
HEALTHCHECK --interval=15s --timeout=10s --start-period=60s --retries=5 \
  CMD ["unsudo", "systemctl", "--user", "is-system-running"]
ENTRYPOINT ["/docker-entrypoint.sh", "unsudo", "/home/user/usernetes/boot/docker-2ndboot.sh"]
