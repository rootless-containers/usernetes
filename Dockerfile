# This Dockerfile can be translated to `docker/dockerfile:1.0-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile  | DOCKER_BUILDKIT=1 docker build  -f -  .

### Version definitions
# 1/12/2019
ARG ROOTLESSKIT_COMMIT=16c6c0fdfddefa63406989f8ad22294bc3b03a34
# 1/12/2019 (v0.3.0-alpha.0)
ARG SLIRP4NETNS_COMMIT=d013231cdc6607788be81599017f9199f634fe0b
# 12/20/2018
ARG RUNC_COMMIT=bbb17efcb4c0ab986407812a31ba333a7450064c
# 01/08/2019
ARG MOBY_COMMIT=f9dbd383bb6e31d97ec276ef7dbf69e89bc22f66
ARG DOCKER_CLI_RELEASE=18.09.1-rc1
# 01/03/2019
ARG CONTAINERD_COMMIT=231bff7f60ce6536fb402c1d2fa7246d0d2e1de1
# 01/07/2019
ARG CRIO_COMMIT=650fae1c52ff809c8447fd6dcdc1e9e3747efe65
# 12/20/2018
ARG CNI_PLUGINS_COMMIT=ee819c71a17d50f27439dbd979337effb2efd21b
# 01/07/2019
ARG KUBERNETES_COMMIT=8b3b5a9fe7b57cfe014927d575a9ad90cb536419
# 01/23/2017 (v.1.7.3.2)
ARG SOCAT_COMMIT=cef0e039a89fe3b38e36090d9fe4be000973e0be
# Kube's build script requires KUBE_GIT_VERSION to be set to a semver string
ARG KUBE_GIT_VERSION=v1.14-usernetes
ARG BAZEL_RELEASE=0.21.0
ARG ETCD_RELEASE=v3.3.11
ARG GOTASK_RELEASE=v2.3.0

### Common base images (common-*)
FROM golang:1.11-alpine AS common-golang-alpine
RUN apk add --no-cache git

FROM common-golang-alpine AS common-golang-alpine-heavy
RUN apk --no-cache add btrfs-progs-dev bash build-base linux-headers libseccomp-dev

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
FROM alpine:3.8 AS slirp4netns-build
RUN apk add --no-cache git build-base autoconf automake libtool linux-headers
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

### Moby (moby-build)
FROM common-golang-alpine-heavy AS moby-base
RUN git clone https://github.com/moby/moby.git /go/src/github.com/docker/docker
WORKDIR /go/src/github.com/docker/docker
ARG MOBY_COMMIT
RUN git pull && git checkout ${MOBY_COMMIT}
COPY ./src/patches/moby /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary

FROM moby-base AS moby-build-docker-init
RUN apk --no-cache add cmake
RUN hack/dockerfile/install/install.sh tini

FROM moby-base AS moby-build-docker-proxy
RUN hack/dockerfile/install/install.sh proxy

FROM moby-base AS moby-build
RUN mkdir /out
ENV DOCKER_BUILDTAGS="seccomp"
# runopt = --mount=type=cache,id=u7s-moby-build-cache,target=/root
RUN ./hack/make.sh .binary && cp -f bundles/.binary/dockerd-dev /out/dockerd
COPY --from=moby-build-docker-init /usr/local/bin/docker-init /out/
COPY --from=moby-build-docker-proxy /usr/local/bin/docker-proxy /out/

#### Docker CLI (dockercli-build)
ARG DOCKER_CLI_RELEASE
FROM docker:$DOCKER_CLI_RELEASE AS dockercli-build
RUN mkdir /out && cp /usr/local/bin/docker /out

### containerd (containerd-build)
FROM common-golang-alpine-heavy AS containerd-build
RUN git clone https://github.com/containerd/containerd.git /go/src/github.com/containerd/containerd
WORKDIR /go/src/github.com/containerd/containerd
ARG CONTAINERD_COMMIT
RUN git pull && git checkout ${CONTAINERD_COMMIT}
COPY ./src/patches/containerd /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary
RUN make EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS='-extldflags "-fno-PIC -static"' BUILDTAGS="netgo osusergo static_build" && \
  mkdir /out && cp bin/containerd bin/containerd-shim bin/containerd-shim-runc-v1 bin/ctr /out

### CRI-O (crio-build)
# We don't use Alpine here so as to build cri-o linked with glibc rather than musl libc.
# TODO: use Alpine again when we figure out how to build cri-o as a static binary (rootless-containers/usernetes#19)
FROM golang:1.11 AS crio-build
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev
RUN git clone https://github.com/kubernetes-incubator/cri-o.git /go/src/github.com/kubernetes-incubator/cri-o
WORKDIR /go/src/github.com/kubernetes-incubator/cri-o
ARG CRIO_COMMIT
RUN git pull && git checkout ${CRIO_COMMIT}
RUN make BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper containers_image_openpgp" binaries && \
  mkdir /out && cp bin/conmon bin/crio /out

### CNI Plugins (cniplugins-build)
FROM common-golang-alpine-heavy AS cniplugins-build
RUN git clone https://github.com/containernetworking/plugins.git /go/src/github.com/containernetworking/plugins
WORKDIR /go/src/github.com/containernetworking/plugins
ARG CNI_PLUGINS_COMMIT
RUN git pull && git checkout ${CNI_PLUGINS_COMMIT}
RUN ./build_linux.sh -buildmode pie -ldflags "-extldflags \"-fno-PIC -static\"" && \
  mkdir /out && mv bin /out/cni

### Kubernetes (k8s-build)
FROM golang:1.11 AS k8s-build
RUN apt-get update && apt-get install -y -q patch
ARG BAZEL_RELEASE
ADD https://github.com/bazelbuild/bazel/releases/download/${BAZEL_RELEASE}/bazel-${BAZEL_RELEASE}-linux-x86_64 /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel
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
RUN bazel build cmd/hyperkube && mkdir /out && cp bazel-bin/cmd/hyperkube/linux_amd64_stripped/hyperkube /out

### socat (socat-build)
FROM ubuntu:18.04 AS socat-build
RUN apt-get update && apt-get install -y autoconf automake libtool build-essential git yodl
RUN git clone git://repo.or.cz/socat.git /socat
WORKDIR /socat
ARG SOCAT_COMMIT
RUN git pull && git checkout ${SOCAT_COMMIT}
RUN autoconf && ./configure LDFLAGS="-static" && make && strip socat && \
  mkdir -p /out && cp -f socat /out

#### etcd (etcd-build)
FROM busybox AS etcd-build
ARG ETCD_RELEASE
RUN mkdir /tmp-etcd out && \
  wget -O - https://github.com/etcd-io/etcd/releases/download/v3.3.11/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz | tar xz -C /tmp-etcd && \
  cp /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcd /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcdctl /out

#### go-task (gotask-build)
FROM busybox AS gotask-build
ARG GOTASK_RELEASE
RUN mkdir /tmp-task /out && \
  wget -O - https://github.com/go-task/task/releases/download/${GOTASK_RELEASE}/task_linux_amd64.tar.gz | tar xz  -C /tmp-task && \
  cp /tmp-task/task /out

### Binaries (bin-main)
FROM scratch AS bin-main
COPY --from=rootlesskit-build /out/* /
COPY --from=slirp4netns-build /out/* /
COPY --from=runc-build /out/* /
COPY --from=moby-build /out/* /
COPY --from=dockercli-build /out/* /
COPY --from=containerd-build /out/* /
COPY --from=crio-build /out/* /
COPY --from=cniplugins-build /out/* /
COPY --from=k8s-build /out/* /
COPY --from=socat-build /out/* /
COPY --from=etcd-build /out/* /
COPY --from=gotask-build /out/* /

#### Test (test-main)
FROM ubuntu:18.04 AS test-main
# libglib2.0: require by conmon
RUN apt-get update && apt-get install -y -q git libglib2.0-dev iproute2 iptables uidmap
RUN useradd --create-home --home-dir /home/user --uid 1000 user
COPY . /home/user/usernetes
COPY --from=bin-main / /home/user/usernetes/bin
RUN mkdir -p /run/user/1000 /home/user/.local && \
  chown -R user:user /run/user/1000 /home/user
USER user
ENV HOME /home/user
ENV USER user
ENV XDG_RUNTIME_DIR=/run/user/1000
WORKDIR /home/user/usernetes
VOLUME /home/user/.local
ENTRYPOINT ["/home/user/usernetes/run.sh"]
