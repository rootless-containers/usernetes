#!/bin/sh
set -e
PATH=$(dirname $0)/bin:$PATH
DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock
export DOCKER_HOST PATH
docker $@
