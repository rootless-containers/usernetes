#!/bin/bash
cd $(realpath $(dirname $0)/..)
set -eux
if ! ./install.sh $@; then
	journalctl -xe --no-pager
	exit 1
fi
exec journalctl -f -n 100
