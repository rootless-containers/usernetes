FROM golang:1.10-alpine
RUN apk add --no-cache git
ARG ROOTLESSKIT_COMMIT
RUN echo ROOTLESSKIT_COMMIT=${ROOTLESSKIT_COMMIT}
RUN git clone https://github.com/rootless-containers/rootlesskit.git /go/src/github.com/rootless-containers/rootlesskit && \
  cd /go/src/github.com/rootless-containers/rootlesskit && git checkout ${ROOTLESSKIT_COMMIT} && \
  CGO_ENABLED=0 go build -o /rootlesskit github.com/rootless-containers/rootlesskit/cmd/rootlesskit
