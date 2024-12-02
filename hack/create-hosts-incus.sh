#!/bin/bash
set -eux -o pipefail
if [ "$#" -lt 2 ]; then
	echo "Usage: $0 DIR INST..."
	exit 1
fi
dir=$1
shift
names=$*

: "${INCUS_IMAGE:="images:ubuntu/24.04/cloud"}"
INCUS="sudo incus"

echo "USER=${USER}"
ssh_config="${dir}/ssh_config"
echo "SSH_CONFIG=${ssh_config}"

# ssh-copy-id wants ~/.ssh to exist
mkdir -p "${HOME}/.ssh"
mkdir -p "${dir}"
prvkey="${dir}/ssh_key"
pubkey="${prvkey}.pub"
if [ ! -e "${pubkey}" ]; then
	ssh-keygen -f "${prvkey}" -q -N ""
fi
echo "IdentityFile ${prvkey}" >"${ssh_config}"

userdata="${dir}/user-data"
if [ ! -e "${userdata}" ]; then
	cat <<EOF >"${userdata}"
#cloud-config
packages:
  - openssh-server
users:
  - name: "${USER}"
    shell: /bin/bash
    ssh-authorized-keys:
      - $(cat "${pubkey}")
  - name: "${USER}-sudo"
    shell: /bin/bash
    ssh-authorized-keys:
      - $(cat "${pubkey}")
    sudo: ALL=(ALL) NOPASSWD:ALL
EOF
fi

for name in ${names}; do
	${INCUS} init "${INCUS_IMAGE}" "${name}" -c security.privileged=true -c security.nesting=true
	${INCUS} config device add "${name}" bind-boot disk source=/boot path=/boot readonly=true
	${INCUS} config set "${name}" user.user-data - <"${userdata}"
	${INCUS} start "${name}"

	# Apply fixes for AppArmor (apparantely only needed on LXD/Incus)
	# `slirp4netns --enable-sandbox` inside LXD/Incus (Ubuntu 24.04) requires amending the AppArmor rule.
	# https://github.com/rootless-containers/slirp4netns/issues/348#issuecomment-2288124206
	${INCUS} shell "${name}" -- bash -c 'echo "pivot_root," >>/etc/apparmor.d/local/slirp4netns'
	# runc requires pivot_root:
	# > runc run failed: unable to start container process: error during container init: error jailing process inside rootfs: pivot_root .: permission denied
	${INCUS} shell "${name}" -- bash -c 'echo "pivot_root," >>/etc/apparmor.d/local/runc'
	# Propagate the profile for /usr/sbin/runc (Canonical's package) to /usr/bin/runc (Docker's package)
	${INCUS} shell "${name}" -- bash -c 'sed -e s@/usr/sbin/runc@/usr/bin/runc@g /etc/apparmor.d/runc > /etc/apparmor.d/usr.bin.runc'
	${INCUS} shell "${name}" -- bash -c 'systemctl restart apparmor'

	sleep 10
	ip="$(${INCUS} exec "${name}" -- ip --json route get 1 | jq -r .[0].prefsrc)"
	echo "Host ${name}" >>"${ssh_config}"
	echo "  Hostname ${ip}" >>"${ssh_config}"
	echo "  # For a test env, the host key can be just ignored"
	echo "  StrictHostKeyChecking=no"
	echo "  UserKnownHostsFile=/dev/null"
	ssh-copy-id -F "${ssh_config}" -i "${prvkey}" -o StrictHostKeyChecking=no "${USER}@${name}"
done
