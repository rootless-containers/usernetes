#!/bin/bash
set -e
cd $(dirname $0)
if [ -z $XDG_RUNTIME_DIR ]; then
	echo "XDG_RUNTIME_DIR needs to be set"
	exit 1
fi
if [ -z $HOME ]; then
	echo "HOME needs to be set"
	exit 1
fi

set -x

systemctl --user reset-failed

# use RootlessKit for removing files owned by sub-IDs.
./bin/rootlesskit rm -rf \
	$XDG_RUNTIME_DIR/{usernetes,containerd,crio,runc} \
	$HOME/.local/share/usernetes \
	$HOME/.local/share/containerd \
	$HOME/.local/share/containers \
	$HOME/.local/share/crio \
	$HOME/.config/usernetes

set +x
echo "You may also want to remove manually: ~/.config/{containerd,containers,crio} ~/.kube"
