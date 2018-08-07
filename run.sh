#!/bin/sh
set -e -x
cd $(dirname $0)

if [ -z $XDG_RUNTIME_DIR ]; then
    echo "XDG_RUNTIME_DIR needs to be set"
    exit 1
fi
PATH=$(pwd)/bin:/sbin:/usr/sbin:$PATH
export PATH
rootlesskit \
    --state-dir $XDG_RUNTIME_DIR/usernetes/rootlesskit \
    --net=slirp4netns --mtu=65520 \
    --copy-up=/etc --copy-up=/run --copy-up=/var/lib --copy-up=/var/log \
    task $@
