#!/bin/bash
set -eu -o pipefail
PATH=$(dirname $0)/bin:$PATH
DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock
export DOCKER_HOST PATH
exec docker $@
