FROM alpine:3.8
RUN apk add --no-cache git build-base autoconf automake libtool linux-headers
RUN git clone https://github.com/rootless-containers/slirp4netns.git /slirp4netns
WORKDIR /slirp4netns
ARG SLIRP4NETNS_COMMIT
RUN git pull && git checkout ${SLIRP4NETNS_COMMIT}
RUN ./autogen.sh && ./configure LDFLAGS="-static" && make && \
  mkdir -p /out && cp -f slirp4netns /out
