#!/bin/sh
set -e -x
cd $(dirname $0)
PATH=$(pwd)/bin:/sbin:/usr/sbin:$PATH
export PATH
rootlesskit \
    --state-dir /tmp/usernetes/rootlesskit \
    --net=slirp4netns --mtu=65520 \
    --copy-up=/etc --copy-up=/run --copy-up=/var/lib --copy-up=/var/log \
    task $@
