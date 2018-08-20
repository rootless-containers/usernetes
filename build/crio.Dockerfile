FROM golang:alpine
RUN apk add --no-cache git build-base gpgme-dev linux-headers glib-dev glib-static
ARG CRIO_COMMIT
RUN echo CRIO_COMMIT=${CRIO_COMMIT} RUNC_COMMIT=${RUNC_COMMIT}

RUN git clone https://github.com/kubernetes-incubator/cri-o.git /go/src/github.com/kubernetes-incubator/cri-o && \
  cd /go/src/github.com/kubernetes-incubator/cri-o && git checkout ${CRIO_COMMIT} && \
  make CFLAGS="-static" BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper" binaries && \
  mkdir -p /crio/cni/plugins/ /crio/cni/conf && \
  cp bin/conmon bin/crio /crio && \
  cp contrib/cni/* /crio/cni/conf && \
  git clone https://github.com/containernetworking/plugins /go/src/github.com/containernetworking/plugins && \
  cd /go/src/github.com/containernetworking/plugins && \
  sh ./build.sh -ldflags "-extldflags -static" && \
  cp bin/* /crio/cni/plugins && \
  git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc && \
  cd /go/src/github.com/opencontainers/runc && git checkout ${RUNC_COMMIT} && \
  make BUILDTAGS="" SHELL=/bin/sh static && \
  cp runc /crio/runc
