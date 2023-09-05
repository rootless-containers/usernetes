#!/bin/bash
set -eu -o pipefail
: "${HOSTNAME:=$(hostname)}"
NODE_SUBNET_ID=$((16#$(echo "${HOSTNAME}" | sha256sum | head -c2)))
NODE_SUBNET=10.100.${NODE_SUBNET_ID}.0/24
echo "${NODE_SUBNET}"
