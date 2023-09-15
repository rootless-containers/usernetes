ARG BASE_IMAGE=docker.io/kindest/node:v1.28.0
ARG CNI_PLUGINS_VERSION=v1.3.0
FROM ${BASE_IMAGE}
# TODO: check SHA256SUMS of cni-plugins
ARG CNI_PLUGINS_VERSION
RUN arch="$(uname -m | sed -e s/x86_64/amd64/ -e s/aarch64/arm64/)" && \
  curl -fsSL https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${arch}-${CNI_PLUGINS_VERSION}.tgz \
  | tar Cxzv /opt/cni/bin
# gettext-base: for `envsubst`
# moreutils: for `sponge`
# socat: for `socat` (to silence "[WARNING FileExisting-socat]" from kubeadm)
RUN apt-get update && apt-get install -y --no-install-recommends \
  gettext-base \
  moreutils \
  socat
ADD Dockerfile.d/u7s-entrypoint.sh /
ENTRYPOINT ["/u7s-entrypoint.sh", "/usr/local/bin/entrypoint", "/sbin/init"]
