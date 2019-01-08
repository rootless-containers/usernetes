#!/bin/bash
# Common functions

# Customizable environment variables:
# * $U7S_DEBUG: enable debug mode if set to "1"

# Environment variables set by this script:
# * $U7S_BASE_DIR: set to the Usernetes base directory
# * $PATH: $U7S_BASE_DIR/bin:/sbin:/usr/sbin are prepended
# * $XDG_DATA_HOME: $HOME/.local/share if not set
# * $XDG_CONFIG_HOME: $HOME/.config if not set
# * $XDG_CACHE_HOME: $HOME/.cache if not set

set -euo pipefail

# logging utilities
function debug::enabled() {
	: ${U7S_DEBUG=0}
	[[ $U7S_DEBUG == 1 ]] || [[ $U7S_DEBUG == true ]]
}

function log::debug() {
	if debug::enabled; then
		echo -e "\e[102m\e[97m[DEBUG]\e[49m\e[39m $@"
	fi
}

function log::info() {
	echo -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}

function log::info_n() {
	echo -n -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}

function log::warning() {
	echo -e "\e[101m\e[97m[WARN]\e[49m\e[39m $@"
}

function log::error() {
	echo -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@"
}

# nsenter utilities
function nsenter::main() {
	: ${_U7S_NSENTER_CHILD=0}
	if [[ $_U7S_NSENTER_CHILD == 0 ]]; then
		_U7S_NSENTER_CHILD=1
		export _U7S_NSENTER_CHILD
		nsenter::_nsenter_retry_loop
		rc=0
		nsenter::_nsenter $@ || rc=$?
		exit $rc
	fi
}

function nsenter::_nsenter_retry_loop() {
	local max_trial=10
	log::info_n "Entering to RootlessKit namespaces: "
	for ((i = 0; i < max_trial; i++)); do
		rc=0
		nsenter::_nsenter echo OK 2>/dev/null || rc=$?
		if [[ rc -eq 0 ]]; then
			return 0
		fi
		echo -n .
		sleep 1
	done
	log::error "nsenter failed after ${max_trial} attempts, RootlessKit not running?"
	return 1
}

function nsenter::_nsenter() {
	local pidfile=$XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid
	if ! [[ -f $pidfile ]]; then
		return 1
	fi
	# TODO(AkihiroSuda): ping to $XDG_RUNTIME_DIR/usernetes/rootlesskit/api.sock
	nsenter -U --preserve-credential -n -m -t $(cat $pidfile) --wd=$PWD -- $@
}

# entrypoint begins
if debug::enabled; then
	log::warning "Running in debug mode (\$U7S_DEBUG)"
	set -x
fi

# verify necessary environment variables
if ! [[ -w $XDG_RUNTIME_DIR ]]; then
	log::error "XDG_RUNTIME_DIR needs to be set and writable"
	return 1
fi
if ! [[ -w $HOME ]]; then
	log::error "HOME needs to be set and writable"
	return 1
fi

# export U7S_BASE_DIR
U7S_BASE_DIR=$(realpath $(dirname $0)/..)
export U7S_BASE_DIR
log::debug "Usernetes base directory (\$U7S_BASE_DIR) = $U7S_BASE_DIR"
if ! [[ -d $U7S_BASE_DIR ]]; then
	log::error "Usernetes base directory ($U7S_BASE_DIR) not found"
	return 1
fi

# export PATH
PATH=$U7S_BASE_DIR/bin:/sbin:/usr/sbin:$PATH
export PATH

# export XDG_{DATA,CONFIG,CACHE}_HOME
: ${XDG_DATA_HOME=$HOME/.local/share}
: ${XDG_CONFIG_HOME=$HOME/.config}
: ${XDG_CACHE_HOME=$HOME/.cache}
export XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME
