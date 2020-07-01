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
systemctl --user -T -f stop --signal=KILL 'u7s-*'
systemctl --user -T disable u7s.target
rm -rf ${config_dir}/systemd/user/u7s*
systemctl --user -T daemon-reload
systemctl --user reset-failed 'u7s-*'
systemctl --user reset-failed 'u7s-*'
systemctl --user reset-failed 'u7s-*'
rm -rf "$XDG_RUNTIME_DIR/usernetes"
