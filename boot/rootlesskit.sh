#!/bin/bash
# Customizable environment variables:
# * $U7S_ROOTLESSKIT_FLAGS
# * $U7S_ROOTLESSKIT_PORTS
# * $U7S_FLANNEL

export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

rk_state_dir=$XDG_RUNTIME_DIR/usernetes/rootlesskit

: ${U7S_ROOTLESSKIT_FLAGS=}
: ${U7S_ROOTLESSKIT_PORTS=}
: ${U7S_FLANNEL=}

: ${_U7S_CHILD=0}
if [[ $_U7S_CHILD == 0 ]]; then
	_U7S_CHILD=1
	: ${U7S_PARENT_IP=$(hostname -I | sed -e 's/ .*//g')}
	export _U7S_CHILD U7S_PARENT_IP
	# Re-exec the script via RootlessKit, so as to create unprivileged {user,mount,network} namespaces.
	#
	# --net specifies the network stack. slirp4netns and VPNKit are supported.
	# Currently, slirp4netns is the fastest.
	# See https://github.com/rootless-containers/rootlesskit for the benchmark result.
	#
	# --copy-up allows removing/creating files in the directories by creating tmpfs and symlinks
	# * /etc: copy-up is required so as to prevent `/etc/resolv.conf` in the
	#         namespace from being unexpectedly unmounted when `/etc/resolv.conf` is recreated on the host
	#         (by either systemd-networkd or NetworkManager)
	# * /run: copy-up is required so that we can create /run/docker (hardcoded for plugins) in our namespace
	# * /var/lib: copy-up is required for several Kube stuff
	# * /opt: copy-up is required for mounting /opt/cni/bin
	rootlesskit \
		--state-dir $rk_state_dir \
		--net=slirp4netns --mtu=65520 --disable-host-loopback --slirp4netns-sandbox=true --slirp4netns-seccomp=true \
		--port-driver=builtin \
		--copy-up=/etc --copy-up=/run --copy-up=/var/lib --copy-up=/opt \
		--pidns \
		$U7S_ROOTLESSKIT_FLAGS \
		$0 $@
else
	# save IP address
	echo $U7S_PARENT_IP >$XDG_RUNTIME_DIR/usernetes/parent_ip

	# Remove symlinks so that the child won't be confused by the parent configuration
	rm -f /run/xtables.lock /run/flannel /etc/cni /etc/containerd /etc/containers /etc/crio /etc/docker /etc/kubernetes

	# Copy CNI config to /etc/cni/net.d (Likely to be hardcoded in CNI installers)
	mkdir -p /etc/cni/net.d
	cp -f $U7S_BASE_DIR/config/cni_net.d/* /etc/cni/net.d
	if [[ $U7S_FLANNEL == 1 ]]; then
		cp -f $U7S_BASE_DIR/config/flannel/cni_net.d/* /etc/cni/net.d
		mkdir -p /run/flannel
	fi
	# Bind-mount /opt/cni/net.d (Likely to be hardcoded in CNI installers)
	mkdir -p /opt/cni/bin
	mount --bind $U7S_BASE_DIR/bin/cni /opt/cni/bin

	# These bind-mounts are needed at the moment because the paths are hard-coded in Kube.
	binds=(/var/lib/kubelet /var/lib/dockershim /var/lib/cni /var/log)
	# /run/docker is hard-coded in Docker for plugins.
	binds+=(/run/docker)
	for f in ${binds[@]}; do
		src=$XDG_DATA_HOME/usernetes/$(echo $f | sed -e s@/@_@g)
		mkdir -p $src $f
		mount --bind $src $f
	done
	rk_pid=$(cat $rk_state_dir/child_pid)
	# workaround for https://github.com/rootless-containers/rootlesskit/issues/37
	# child_pid might be created before the child is ready
	echo $rk_pid >$rk_state_dir/_child_pid.u7s-ready
	log::info "RootlessKit ready, PID=${rk_pid}, state directory=$rk_state_dir ."
	log::info "Hint: You can enter RootlessKit namespaces by running \`nsenter -U --preserve-credential -n -m -t ${rk_pid}\`."
	if [[ -n $U7S_ROOTLESSKIT_PORTS ]]; then
		rootlessctl --socket $rk_state_dir/api.sock add-ports $U7S_ROOTLESSKIT_PORTS
	fi
	rc=0
	if [[ $# -eq 0 ]]; then
		sleep infinity || rc=$?
	else
		$@ || rc=$?
	fi
	log::info "RootlessKit exiting (status=$rc)"
	exit $rc
fi
