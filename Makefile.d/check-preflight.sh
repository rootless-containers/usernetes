#!/bin/bash
set -eu

function WARNING() {
	echo >&2 -e "\e[101m\e[97m[WARNING]\e[49m\e[39m $@"
}

function ERROR() {
	echo >&2 -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@"
}

: "${DOCKER:=docker}"

# Check hard dependency commands
for f in make jq "${DOCKER}"; do
	if ! command -v "${f}" >/dev/null 2>&1; then
		ERROR "Command \"${f}\" is not installed"
		exit 1
	fi
done

# Check soft dependency commands
for f in kubectl; do
	if ! command -v "${f}" >/dev/null 2>&1; then
		WARNING "Command \"${f}\" is not installed"
	fi
done

# Check if Docker is running in Rootless mode
# TODO: support Podman?
if "${DOCKER}" info --format '{{json .SecurityOptions}}' | grep -q "name=rootless"; then
	# Check systemd lingering: https://rootlesscontaine.rs/getting-started/common/login/
	if command -v loginctl >/dev/null 2>&1; then
		if [ "$(loginctl list-users --output json | jq ".[] | select(.uid == "${UID}").linger")" != "true" ]; then
			WARNING 'systemd lingering is not enabled. Run `sudo loginctl enable-linger $(whoami)` to enable it, otherwise Kubernetes will exit on logging out.'
		fi
	else
		WARNING "systemd lingering is not enabled?"
	fi

	# Check cgroup config
	if [[ ! -f /sys/fs/cgroup/cgroup.controllers ]]; then
		ERROR "Needs cgroup v2, see https://rootlesscontaine.rs/getting-started/common/cgroup2/"
		exit 1
	else
		f="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers"
		if [[ ! -f $f ]]; then
			ERROR "systemd not running? file not found: $f"
			exit 1
		fi
		if ! grep -q cpu "${f}"; then
			WARNING "cpu controller might not be enabled, you need to configure /etc/systemd/system/user@.service.d , see https://rootlesscontaine.rs/getting-started/common/cgroup2/"
		elif ! grep -q memory "${f}"; then
			WARNING "memory controller might not be enabled, you need to configure /etc/systemd/system/user@.service.d , see https://rootlesscontaine.rs/getting-started/common/cgroup2/"
		fi
	fi
else
	WARNING "Docker does not seem running in Rootless mode"
fi

# Check kernel modules
for f in ip6_tables ip6table_nat ip_tables iptable_nat vxlan; do
	if ! grep -qw "^$f" /proc/modules; then
		WARNING "Kernel module \"${f}\" does not seem loaded? (negligible if built-in to the kernel)"
	fi
done
