FROM alpine:3.8
RUN apk add --no-cache git build-base autoconf automake libtool linux-headers
ARG SLIRP4NETNS_COMMIT
RUN echo SLIRP4NETNS_COMMIT=${SLIRP4NETNS_COMMIT}
RUN git clone https://github.com/rootless-containers/slirp4netns.git /slirp4netns && \
  cd /slirp4netns && git checkout ${SLIRP4NETNS_COMMIT} && \
  ./autogen.sh && ./configure LDFLAGS="-static" && make
