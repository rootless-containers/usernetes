FROM golang:1.11-alpine AS moby-base
RUN apk --no-cache add btrfs-progs-dev bash build-base git libseccomp-dev
RUN git clone https://github.com/moby/moby.git /go/src/github.com/docker/docker
WORKDIR /go/src/github.com/docker/docker
ARG MOBY_COMMIT
RUN git pull && git checkout ${MOBY_COMMIT}
COPY ./patches/moby /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary

FROM moby-base AS docker-init
RUN apk --no-cache add cmake
RUN hack/dockerfile/install/install.sh tini

FROM moby-base AS docker-proxy
RUN hack/dockerfile/install/install.sh proxy

FROM moby-base
RUN mkdir -p /out
COPY --from=docker-init /usr/local/bin/docker-init /out/
COPY --from=docker-proxy /usr/local/bin/docker-proxy /out/
ENV DOCKER_BUILDTAGS="seccomp"
RUN ./hack/make.sh .binary && cp -f bundles/.binary/dockerd-dev /out/dockerd
