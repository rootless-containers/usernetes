FROM golang:1.11-alpine
RUN apk add --no-cache git
RUN git clone https://github.com/rootless-containers/rootlesskit.git /go/src/github.com/rootless-containers/rootlesskit
WORKDIR /go/src/github.com/rootless-containers/rootlesskit
ARG ROOTLESSKIT_COMMIT
RUN git pull && git checkout ${ROOTLESSKIT_COMMIT}
RUN CGO_ENABLED=0 go build -o /rootlesskit github.com/rootless-containers/rootlesskit/cmd/rootlesskit
