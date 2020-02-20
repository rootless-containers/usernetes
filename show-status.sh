#!/bin/bash
set -e -o pipefail
set -x
systemctl --user --no-pager status
systemctl --user --all --no-pager list-units 'u7s-*'
