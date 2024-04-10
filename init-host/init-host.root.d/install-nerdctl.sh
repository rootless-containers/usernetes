#!/bin/bash
set -eux -o pipefail
if [ "$(id -u)" != "0" ]; then
	echo "Must run as the root"
	exit 1
fi

VERSION="2.0.0-beta.4"
SHASHA="dfc9b122fea81a661f33a4013662b5def8a98fce84c257b8ad60e4279d11183e"

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
