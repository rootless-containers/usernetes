FROM golang:1.11-alpine
RUN apk add --no-cache btrfs-progs-dev build-base git
RUN git clone https://github.com/containerd/containerd.git /go/src/github.com/containerd/containerd
WORKDIR /go/src/github.com/containerd/containerd
ARG CONTAINERD_COMMIT
RUN git pull && git checkout ${CONTAINERD_COMMIT}
RUN make EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS='-extldflags "-fno-PIC -static"' BUILDTAGS="netgo osusergo static_build" && \
  mkdir -p /out && cp -f bin/containerd bin/containerd-shim bin/containerd-shim-runc-v1 bin/ctr /out
