# We don't use Alpine here so as to build cri-o linked with glibc rather than musl libc.
# TODO: use Alpine again when we figure out how to build cri-o as a static binary (rootless-containers/usernetes#19)
FROM golang:1.10
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev
ARG CRIO_COMMIT
ARG RUNC_COMMIT
ARG CNI_PLUGINS_COMMIT
RUN echo CRIO_COMMIT=${CRIO_COMMIT} RUNC_COMMIT=${RUNC_COMMIT} CNI_PLUGINS_COMMIT=${CNI_PLUGINS_COMMIT}

RUN git clone https://github.com/kubernetes-incubator/cri-o.git /go/src/github.com/kubernetes-incubator/cri-o && \
  cd /go/src/github.com/kubernetes-incubator/cri-o && git checkout ${CRIO_COMMIT} && \
  make BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper containers_image_openpgp" binaries && \
  mkdir -p /crio/cni/plugins/ /crio/cni/conf && \
  cp bin/conmon bin/crio /crio && \
  cp contrib/cni/* /crio/cni/conf && \
  git clone https://github.com/containernetworking/plugins /go/src/github.com/containernetworking/plugins && \
  cd /go/src/github.com/containernetworking/plugins && git checkout ${CNI_PLUGINS_COMMIT} && \
  sh ./build.sh -ldflags "-extldflags -static" && \
  cp bin/* /crio/cni/plugins && \
  git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc && \
  cd /go/src/github.com/opencontainers/runc && git checkout ${RUNC_COMMIT} && \
  make BUILDTAGS="" SHELL=/bin/sh static && \
  cp runc /crio/runc
