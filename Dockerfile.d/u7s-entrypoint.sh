#!/bin/bash
set -eux -o pipefail

# Append "---node-ip=${U7S_HOST_IP}" to "KUBELET_EXTRA_ARGS=..." in /etc/default/kubelet
sed -e "s/\(^KUBELET_EXTRA_ARGS=.*\)/\\1 --node-ip=${U7S_HOST_IP}/" </etc/default/kubelet | sponge /etc/default/kubelet

# Let kubelet recognize ${U7S_HOST_IP} as its IP:
# https://github.com/kubernetes/kubernetes/issues/54337#issuecomment-363597985
ip addr add "${U7S_HOST_IP}" dev eth0

cat <<EOF >/u7s-flanneld-wrapper.sh
#!/bin/sh
# Usage: /u7s-flanneld-wrapper.sh /opt/bin/flanneld --ip-masq --kube-subnet-mgr ...
# This script is expected to be mounted inside a "docker.io/flannel/flannel" container.
set -eux
"\$@" --public-ip="${U7S_HOST_IP}"
EOF
chmod +x /u7s-flanneld-wrapper.sh

exec "$@"
