FROM golang:1.11-alpine
RUN apk add --no-cache bash build-base git libseccomp-dev linux-headers
RUN git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc
WORKDIR /go/src/github.com/opencontainers/runc
ARG RUNC_COMMIT
RUN git pull && git checkout ${RUNC_COMMIT}
RUN make BUILDTAGS="seccomp" static && \
  mkdir -p /out && cp -f runc /out
