#!/bin/sh
set -e -x
cd $(dirname $0)
PATH=$(pwd)/bin:/sbin:/usr/sbin:$PATH
export PATH
docker-rootlesskit \
    --state-dir /tmp/usernetes/rootlesskit \
    --net=vpnkit --vpnkit-binary=docker-vpnkit \
    --copy-up=/etc --copy-up=/run --copy-up=/var/lib --copy-up=/var/log \
    task $@
