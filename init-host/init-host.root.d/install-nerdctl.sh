#!/bin/bash
set -eux -o pipefail
if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

VERSION="2.0.1"
SHASHA="608439147e8ec964c8083863890177709fb42b8a4d5aba00ed5c33a8205b5e8c"

arch=""
case "$(uname -m)" in
"x86_64")
	arch="amd64"
	;;
"aarch64")
	arch="arm64"
	;;
*)
	echo >&2 "Unsupported architecture"
	exit 1
	;;
esac

mkdir -p /root/nerdctl.tmp
(
	cd /root/nerdctl.tmp
	curl -fSLO https://github.com/containerd/nerdctl/releases/download/v${VERSION}/nerdctl-full-${VERSION}-linux-${arch}.tar.gz
	curl -fSLO https://github.com/containerd/nerdctl/releases/download/v${VERSION}/SHA256SUMS
	[ "$(sha256sum SHA256SUMS | awk '{print $1}')" = "${SHASHA}" ]
	sha256sum --check --ignore-missing SHA256SUMS
	tar Cxzvvf /usr/local nerdctl-full-${VERSION}-linux-${arch}.tar.gz
)
rm -rf /root/nerdctl.tmp

if [ -e /etc/apparmor.d/rootlesskit ]; then
	# https://rootlesscontaine.rs/getting-started/common/apparmor/
	sed -e s@/usr/bin/rootlesskit@/usr/local/bin/rootlesskit@g /etc/apparmor.d/rootlesskit >/etc/apparmor.d/usr.local.bin.rootlesskit
	systemctl restart apparmor
fi
