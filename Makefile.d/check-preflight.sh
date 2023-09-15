#!/bin/bash
set -eu

function INFO() {
	echo >&2 -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}
function WARNING() {
	echo >&2 -e "\e[101m\e[97m[WARNING]\e[49m\e[39m $@"
}

function ERROR() {
	echo >&2 -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@"
}

script_dir="$(dirname "$0")"
detect_engine="${script_dir}"/detect_container_engine.sh
: "${CONTAINER_ENGINE:=$("${detect_engine}" CONTAINER_ENGINE)}"
: "${CONTAINER_ENGINE_TYPE:=$("${detect_engine}" CONTAINER_ENGINE_TYPE)}"
: "${QUICK:=0}"
: "${BUSYBOX_IMAGE:=docker.io/library/busybox:latest}"

if [ -z "${CONTAINER_ENGINE}" ] || [ -z "${CONTAINER_ENGINE_TYPE}" ]; then
	ERROR "No container engine was detected"
	exit 1
fi
INFO "Detected container engine type: ${CONTAINER_ENGINE_TYPE}"

# Check hard dependency commands
for f in make jq "${CONTAINER_ENGINE}"; do
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

rootless=
case "${CONTAINER_ENGINE_TYPE}" in
"podman")
	if [ "$(${CONTAINER_ENGINE} info --format '{{.Host.Security.Rootless}}')" = "true" ]; then
		rootless=1
	fi
	;;
*)
	if ${CONTAINER_ENGINE} info --format '{{json .SecurityOptions}}' | grep -q "name=rootless"; then
		rootless=1
	fi
	;;
esac

# Check if the container engine is running in Rootless mode
if [ "${rootless}" = "1" ]; then
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
	WARNING "Container engine (${CONTAINER_ENGINE}) does not seem running in Rootless mode"
fi

# Check kernel modules
for f in br_netfilter ip6_tables ip6table_nat ip_tables iptable_nat vxlan; do
	if ! grep -qw "^$f" /proc/modules; then
		WARNING "Kernel module \"${f}\" does not seem loaded? (negligible if built-in to the kernel)"
	fi
done

if [ "$QUICK" != "1" ]; then
	# Check net.ipv4.conf.default.rp_filter in the container engine's network namespace. (e.g., netns of dockerd)
	# The value can be 0 (disabled) or 2 (loose), must not be 1 (strict).
	if [ "$(${CONTAINER_ENGINE} run --rm --net=host "${BUSYBOX_IMAGE}" sysctl -n net.ipv4.conf.default.rp_filter)" == "1" ]; then
		ERROR "sysctl value \"net.ipv4.conf.default.rp_filter\" must be 0 (disabled) or 2 (loose) in the container engine's network namespace"
		exit 1
	fi
fi
