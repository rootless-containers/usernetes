# this dockerfile can be translated to `docker/dockerfile:1-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile  | DOCKER_BUILDKIT=1 docker build  -f -  .

### Version definitions
# use ./hack/show-latest-commits.sh to get the latest commits

# 2020-01-26T12:41:45Z
ARG ROOTLESSKIT_COMMIT=1d2bbb25313a6f2dccc674ee96a62c4e343178ef
# 2019-12-18T03:10:18Z
ARG SLIRP4NETNS_COMMIT=a8414d1d1629f6f7a93b60b55e183a93d10d9a1c
# 2020-02-03T11:41:07Z
ARG RUNC_COMMIT=e6555cc01a92b599bef90dbe8cb3b7bb74391da9
# 2020-02-13T22:22:59Z
ARG CONTAINERD_COMMIT=7811aa755265ba3f017683afb1ee3b5a1e0f29b4
# 2020-02-13T12:49:01Z
ARG CRIO_COMMIT=ba4a8cdc9470a099563b78686a12ab92eb5f0fd1
# 2020-02-14T03:48:26Z
ARG KUBERNETES_COMMIT=4c0871751308d93e99e58fdc0c3503a9f59555c3

# Version definitions (cont.)
ARG CONMON_RELEASE=v2.0.10
# Kube's build script requires KUBE_GIT_VERSION to be set to a semver string
ARG KUBE_GIT_VERSION=v1.18.0-usernetes
ARG SOCAT_RELEASE=1.7.3.4
ARG CNI_PLUGINS_RELEASE=v0.8.5
ARG FLANNEL_RELEASE=v0.11.0
ARG ETCD_RELEASE=v3.4.3

### Common base images (common-*)
FROM alpine:3.11 AS common-alpine
RUN apk add --no-cache git build-base autoconf automake libtool

FROM golang:1.13-alpine AS common-golang-alpine
RUN apk add --no-cache git

FROM common-golang-alpine AS common-golang-alpine-heavy
RUN apk --no-cache add bash build-base linux-headers libseccomp-dev

### RootlessKit (rootlesskit-build)
FROM common-golang-alpine AS rootlesskit-build
RUN git clone https://github.com/rootless-containers/rootlesskit.git /go/src/github.com/rootless-containers/rootlesskit
WORKDIR /go/src/github.com/rootless-containers/rootlesskit
ARG ROOTLESSKIT_COMMIT
RUN git pull && git checkout ${ROOTLESSKIT_COMMIT}
ENV CGO_ENABLED=0
RUN mkdir /out && \
  go build -o /out/rootlesskit github.com/rootless-containers/rootlesskit/cmd/rootlesskit && \
  go build -o /out/rootlessctl github.com/rootless-containers/rootlesskit/cmd/rootlessctl

#### slirp4netns (slirp4netns-build)
FROM common-alpine AS slirp4netns-build
RUN apk add --no-cache linux-headers glib-dev glib-static libcap-static libcap-dev libseccomp-dev
RUN git clone https://github.com/rootless-containers/slirp4netns.git /slirp4netns
WORKDIR /slirp4netns
ARG SLIRP4NETNS_COMMIT
RUN git pull && git checkout ${SLIRP4NETNS_COMMIT}
RUN ./autogen.sh && ./configure LDFLAGS="-static" && make && \
  mkdir /out && cp slirp4netns /out

### runc (runc-build)
FROM common-golang-alpine-heavy AS runc-build
RUN git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc
WORKDIR /go/src/github.com/opencontainers/runc
ARG RUNC_COMMIT
RUN git pull && git checkout ${RUNC_COMMIT}
RUN make BUILDTAGS="seccomp" static && \
  mkdir /out && cp runc /out

### containerd (containerd-build)
FROM common-golang-alpine-heavy AS containerd-build
RUN git clone https://github.com/containerd/containerd.git /go/src/github.com/containerd/containerd
WORKDIR /go/src/github.com/containerd/containerd
ARG CONTAINERD_COMMIT
RUN git pull && git checkout ${CONTAINERD_COMMIT}
# workaround: https://github.com/containerd/containerd/issues/3646
RUN ./script/setup/install-dev-tools
RUN make EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS='-extldflags "-fno-PIC -static"' BUILDTAGS="netgo osusergo static_build no_devmapper no_btrfs" \
  bin/containerd bin/containerd-shim-runc-v2 bin/ctr && \
  mkdir /out && cp bin/containerd bin/containerd-shim-runc-v2 bin/ctr /out

### CRI-O (crio-build)
FROM common-golang-alpine-heavy AS crio-build
RUN git clone https://github.com/cri-o/cri-o.git /go/src/github.com/cri-o/cri-o
WORKDIR /go/src/github.com/cri-o/cri-o
ARG CRIO_COMMIT
RUN git pull && git checkout ${CRIO_COMMIT}
RUN EXTRA_LDFLAGS='-linkmode external -extldflags "-static"' make binaries && \
  mkdir /out && cp bin/crio bin/crio-status bin/pinns /out

### conmon (conmon-build)
FROM common-golang-alpine-heavy AS conmon-build
RUN apk add --no-cache glib-dev glib-static
RUN git clone https://github.com/containers/conmon.git /go/src/github.com/containers/conmon
WORKDIR /go/src/github.com/containers/conmon
ARG CONMON_RELEASE
RUN git pull && git checkout ${CONMON_RELEASE}
RUN make static && mkdir /out && cp bin/conmon /out

### CNI Plugins (cniplugins-build)
FROM busybox AS cniplugins-build
ARG CNI_PLUGINS_RELEASE
RUN mkdir -p /out/cni && \
 wget -O - https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_RELEASE}/cni-plugins-linux-amd64-${CNI_PLUGINS_RELEASE}.tgz | tar xz -C /out/cni

### Kubernetes (k8s-build)
FROM common-golang-alpine-heavy AS k8s-build
RUN apk add --no-cache rsync
RUN git clone https://github.com/kubernetes/kubernetes.git /kubernetes
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
# runopt = --mount=type=cache,id=u7s-k8s-build-cache,target=/root
RUN KUBE_STATIC_OVERRIDES=kubelet \
  make kube-apiserver kube-controller-manager kube-proxy kube-scheduler kubectl kubelet && \
  mkdir /out && cp _output/bin/kube* /out

### socat (socat-build)
FROM common-alpine AS socat-build
ARG SOCAT_RELEASE
RUN wget -O - http://www.dest-unreach.org/socat/download/socat-${SOCAT_RELEASE}.tar.gz | tar xz -C /
WORKDIR /socat-${SOCAT_RELEASE}
RUN LIBS="-static" ./configure -q && make socat && strip socat && \
  mkdir -p /out && cp -f socat /out

#### flannel (flannel-build)
FROM busybox AS flannel-build
ARG FLANNEL_RELEASE
RUN mkdir -p /out && \
  wget -O /out/flanneld https://github.com/coreos/flannel/releases/download/${FLANNEL_RELEASE}/flanneld-amd64 && \
  chmod +x /out/flanneld

#### etcd (etcd-build)
FROM busybox AS etcd-build
ARG ETCD_RELEASE
RUN mkdir /tmp-etcd out && \
  wget -O - https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz | tar xz -C /tmp-etcd && \
  cp /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcd /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcdctl /out

### Binaries (bin-main)
FROM scratch AS bin-main
COPY --from=rootlesskit-build /out/* /
COPY --from=slirp4netns-build /out/* /
COPY --from=runc-build /out/* /
COPY --from=containerd-build /out/* /
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
  dnf install -y findutils git iproute iptables hostname procps-ng \
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
