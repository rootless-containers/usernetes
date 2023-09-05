ARG BASE_IMAGE=kindest/node:v1.27.3

# TODO: use `ADD --checksum=sha256...`
FROM scratch AS cni-plugins-amd64
ADD https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz /cni-plugins.tgz

FROM scratch AS cni-plugins-arm64
ADD https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz /cni-plugins.tgz

ARG TARGETARCH
FROM cni-plugins-$TARGETARCH AS cni-plugins

ARG BASE_IMAGE
FROM ${BASE_IMAGE}
RUN --mount=type=bind,from=cni-plugins,dst=/mnt/tmp \
  tar Cxzvf /opt/cni/bin /mnt/tmp/cni-plugins.tgz
# gettext-base: for `envsubst`
# moreutils: for `sponge`
# socat: for `socat` (to silence "[WARNING FileExisting-socat]" from kubeadm)
RUN apt-get update && apt-get install -y --no-install-recommends \
  gettext-base \
  moreutils \
  socat
ADD Dockerfile.d/u7s-entrypoint.sh /
ENTRYPOINT ["/u7s-entrypoint.sh", "/usr/local/bin/entrypoint", "/sbin/init"]
