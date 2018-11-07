# We don't use Alpine here so as to build cri-o linked with glibc rather than musl libc.
# TODO: use Alpine again when we figure out how to build cri-o as a static binary (rootless-containers/usernetes#19)
FROM golang:1.11 AS base
RUN apt-get update && apt-get install -y build-essential libglib2.0-dev
RUN git clone https://github.com/kubernetes-incubator/cri-o.git /go/src/github.com/kubernetes-incubator/cri-o
WORKDIR /go/src/github.com/kubernetes-incubator/cri-o
ARG CRIO_COMMIT
RUN git pull && git checkout ${CRIO_COMMIT}
RUN make BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper containers_image_openpgp" binaries && \
  mkdir -p /out && cp -f bin/conmon bin/crio /out
