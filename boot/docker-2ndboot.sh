#!/bin/bash
cd $(realpath $(dirname $0)/..)
set -eux
./install.sh $@
exec journalctl -f -n 100
