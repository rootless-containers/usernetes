#!/bin/bash
set -e -o pipefail
cd $(dirname $0)
if [ -z $HOME ]; then
	echo "HOME needs to be set"
	exit 1
fi
config_dir="$HOME/.config"
if [ -n "$XDG_CONFIG_HOME" ]; then
	config_dir="$XDG_CONFIG_HOME"
fi
set -u
set +e
set -x
systemctl --user -T -f stop u7s.target
systemctl --user -T disable u7s.target
rm -rf ${config_dir}/systemd/user/u7s*
systemctl --user -T daemon-reload
systemctl --user --no-pager status
systemctl --user --all --no-pager list-units 'u7s-*'
set -x
echo "Hint: \`systemctl --user reset-failed\` to reset failed services."
