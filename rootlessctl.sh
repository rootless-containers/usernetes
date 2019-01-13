#!/bin/bash
set -eu -o pipefail
exec $(dirname $0)/bin/rootlessctl --socket $XDG_RUNTIME_DIR/usernetes/rootlesskit/api.sock $@
