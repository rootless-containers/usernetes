#!/bin/bash
set -eu -o pipefail
exec $(dirname $0)/bin/task $@
