# We don't use Alpine here so as to build cri-o linked with glibc rather than musl libc.
# TODO: use Alpine again when we figure out how to build cri-o as a static binary (rootless-containers/usernetes#19)
FROM golang:1.11 AS base
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev
ARG CRIO_COMMIT
ARG RUNC_COMMIT
ARG CNI_PLUGINS_COMMIT

FROM base as cri-o
RUN git clone https://github.com/kubernetes-incubator/cri-o.git /go/src/github.com/kubernetes-incubator/cri-o
WORKDIR /go/src/github.com/kubernetes-incubator/cri-o
RUN git pull && git checkout ${CRIO_COMMIT}
RUN make BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper containers_image_openpgp" binaries && \
  mkdir -p /crio/cni/plugins/ /crio/cni/conf && \
  mkdir -p /crio/cni && \
  cp bin/conmon bin/crio /crio && \
  cp contrib/cni/* /crio/cni/conf

FROM base AS cni
RUN git clone https://github.com/containernetworking/plugins /go/src/github.com/containernetworking/plugins
WORKDIR /go/src/github.com/containernetworking/plugins
RUN git pull && git checkout ${CNI_PLUGINS_COMMIT}
RUN ./build.sh -ldflags "-extldflags -static" && \
  mkdir -p /crio/cni/plugins && \
  cp bin/* /crio/cni/plugins

FROM base AS runc
RUN git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc
WORKDIR /go/src/github.com/opencontainers/runc
RUN git pull && git checkout ${RUNC_COMMIT}
RUN make BUILDTAGS="" SHELL=/bin/sh static && \
  mkdir -p /crio && \
  cp runc /crio

FROM base
RUN mkdir -p /crio
COPY --from=cri-o /crio/* /crio/
COPY --from=cni /crio/* /crio/
COPY --from=runc /crio/* /crio/
