#!/bin/sh
set -e -x
cd $(dirname $0)
if [ -z $XDG_RUNTIME_DIR ]; then
    echo "XDG_RUNTIME_DIR needs to be set"
    exit 1
fi
if [ -z $HOME ]; then
    echo "HOME needs to be set"
    exit 1
fi

# use RootlessKit for removing files owned by sub-IDs.
./bin/rootlesskit rm -rf $XDG_RUNTIME_DIR/usernetes $HOME/.local/share/usernetes $HOME/.local/share/docker $HOME/.local/share/containers

echo "You may also want to remove manually: ~/.config/{docker,crio,usernetes} ~/.docker ~/.kube"
