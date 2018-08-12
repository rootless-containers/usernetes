#!/bin/sh
set -e -x
if [ -z $_USERNETES_CHILD ]; then
    cd $(dirname $0)
    if [ -z $XDG_RUNTIME_DIR ]; then
        echo "XDG_RUNTIME_DIR needs to be set"
        exit 1
    fi
    if [ -z $HOME ]; then
        echo "HOME needs to be set"
        exit 1
    fi
    PATH=$(pwd)/bin:/sbin:/usr/sbin:$PATH
    _USERNETES_CHILD=1
    export PATH _USERNETES_CHILD
    # copy-up allows removing/creating files in the directories
    rootlesskit \
        --state-dir $XDG_RUNTIME_DIR/usernetes/rootlesskit \
        --net=slirp4netns --mtu=65520 \
        --copy-up=/etc --copy-up=/run --copy-up=/var/lib \
        $0 $@
else
    [ $_USERNETES_CHILD = 1 ]
    # These bind-mounts are needed at the moment because the paths are hard-coded in Kube.
    for f in /var/lib/kubelet /var/lib/dockershim /var/lib/cni /var/log; do
        src=$HOME/.local/share/usernetes/$(echo $f | sed -e s@/@_@g)
        mkdir -p $src $f
        mount --bind $src $f
    done
    mkdir -p $XDG_RUNTIME_DIR/usernetes/_run_docker /run/docker
    mount --bind $XDG_RUNTIME_DIR/usernetes/_run_docker /run/docker
    rm -f /run/xtables.lock
    task $@
fi
