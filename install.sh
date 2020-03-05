#!/bin/bash
set -e -o pipefail

function INFO() {
	echo -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}

function ERROR() {
	echo >&2 -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@"
}

### Detect base dir
cd $(dirname $0)
base=$(realpath $(pwd))

### Detect config dir
set +u
if [ -z "$HOME" ]; then
	ERROR "HOME needs to be set"
	exit 1
fi
config_dir="$HOME/.config"
if [ -n "$XDG_CONFIG_HOME" ]; then
	config_dir="$XDG_CONFIG_HOME"
fi
set -u

### Parse args
arg0=$0
start="u7s.target"
cri="containerd"
cni=""
publish=""
cidr=""
kubeconfig=""
function usage() {
	echo "Usage: ${arg0} [OPTION]..."
	echo "Install Usernetes systemd units to ${config_dir}/systemd/unit ."
	echo
	echo "  --start=UNIT        Enable and start the specified target after the installation, e.g. \"u7s.target\". Set to an empty to disable autostart. (Default: \"$start\")"
	echo "  --cri=RUNTIME       Specify CRI runtime, \"containerd\" or \"crio\". (Default: \"$cri\")"
	echo '  --cni=RUNTIME       Specify CNI, an empty string (none) or "flannel". (Default: none)'
	echo "  -p, --publish=PORT  Publish ports in RootlessKit's network namespace, e.g. \"0.0.0.0:10250:10250/tcp\". Can be specified multiple times. (Default: none)"
	echo "  --cidr=CIDR         Specify CIDR of RootlessKit's network namespace, e.g. \"10.0.100.0/24\". (Default: none)"
	echo "  --kubeconfig=FILE   Specify kubeconfig."
	echo
	echo "Examples:"
	echo "  # The default options"
	echo "  ${arg0}"
	echo
	echo "  # Use CRI-O as the CRI runtime"
	echo "  ${arg0} --cri=crio"
	echo
	echo "Examples (multi-node cluster with flannel):"
	echo "  # Master (2379/tcp: etcd, 8080/tcp: kube-apiserver, 10251/tcp: kube-scheduler, 10252/tcp: kube-controller-manager)"
	echo "  ${arg0} --start=u7s-master-with-etcd.target --cri=\\"
	echo '    --cni=flannel --cidr=10.0.100.0/24\'
	echo "    -p 0.0.0.0:2379:2379/tcp -p 0.0.0.0:8080:8080/tcp -p 0.0.0.0:10251:10251/tcp -p 0.0.0.0:10252:10252/tcp"
	echo
	echo "  # Node  (10250/tcp: kubelet, 8472/udp: flannel)"
	echo "  ${arg0} --start=u7s-node.target --cri=containerd\\"
	echo '    --cni=flannel --cidr=10.0.102.0/24\'
	echo '    -p 0.0.0.0:10250:10250/tcp -p 0.0.0.0:8472:8472/udp\'
	echo "    --kubeconfig=config/docker-compose-master.kubeconfig"
	echo
	echo 'Use `uninstall.sh` for uninstallation.'
	echo
	echo 'Hint: `sudo loginctl enable-linger` to start user services automatically on the system start up.'
}

set +e
args=$(getopt -o hp: --long help,publish:,start:,cri:,cni:,cidr:,kubeconfig: -n $arg0 -- "$@")
getopt_status=$?
set -e
if [ $getopt_status != 0 ]; then
	usage
	exit $getopt_status
fi
eval set -- "$args"
while true; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		shift
		;;
	-p | --publish)
		publish="$publish $2"
		shift 2
		;;
	--start)
		start="$2"
		shift 2
		;;
	--cri)
		cri="$2"
		case "$cri" in
		"" | containerd | crio) ;;

		*)
			ERROR "Unknown CRI runtime \"$cri\". Supported values: \"containerd\" (default) \"crio\" \"\"."
			exit 1
			;;
		esac
		shift 2
		;;
	--cni)
		cni="$2"
		case "$cni" in
		"" | "flannel") ;;

		*)
			ERROR "Unknown CNI \"$cni\". Supported values: \"\" (default) \"flannel\" ."
			exit 1
			;;
		esac
		shift 2
		;;
	--cidr)
		cidr="$2"
		shift 2
		;;
	--kubeconfig)
		kubeconfig="$2"
		if [ -n "$kubeconfig" ]; then
			kubeconfig=$(realpath $kubeconfig)
		fi
		shift 2
		;;
	--)
		shift
		break
		;;
	*)
		break
		;;
	esac
done

### Create EnvironmentFile (~/.config/usernetes/env)
mkdir -p ${config_dir}/usernetes
cat /dev/null >${config_dir}/usernetes/env
cat <<EOF >>${config_dir}/usernetes/env
U7S_ROOTLESSKIT_PORTS=${publish}
EOF
if [ "$cni" = "flannel" ]; then
	cat <<EOF >>${config_dir}/usernetes/env
U7S_FLANNEL=1
EOF
fi
if [ -n "$cidr" ]; then
	cat <<EOF >>${config_dir}/usernetes/env
U7S_ROOTLESSKIT_FLAGS=--cidr=${cidr}
EOF
fi
if [ -n "$kubeconfig" ]; then
	cat <<EOF >>${config_dir}/usernetes/env
U7S_KUBECONFIG=${kubeconfig}
EOF
fi

### Begin installation
INFO "Base dir: ${base}"
mkdir -p ${config_dir}/systemd/user
function x() {
	name=$1
	path=${config_dir}/systemd/user/${name}
	INFO "Installing $path"
	cat >$path
}

service_common="WorkingDirectory=${base}
EnvironmentFile=${config_dir}/usernetes/env
Restart=on-failure
LimitNOFILE=65536
"

### u7s
cat <<EOF | x u7s.target
[Unit]
Description=Usernetes target (all components in the single node)
Requires=u7s-master-with-etcd.target u7s-node.target
After=u7s-master-with-etcd.target u7s-node.target

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | x u7s-master-with-etcd.target
[Unit]
Description=Usernetes target for Kubernetes master components (including etcd)
Requires=u7s-etcd.target u7s-master.target
After=u7s-etcd.target u7s-master.target
PartOf=u7s.target

[Install]
WantedBy=u7s.target
EOF

### RootlessKit
cat <<EOF | x u7s-rootlesskit.service
[Unit]
Description=Usernetes RootlessKit service
PartOf=u7s.target

[Service]
ExecStartPre=/bin/bash -xec "cd \$XDG_RUNTIME_DIR; ${base}/bin/rootlesskit rm -rf usernetes containerd crio runc"
ExecStart=${base}/boot/rootlesskit.sh
${service_common}
EOF

### etcd
# TODO: support running without RootlessKit
cat <<EOF | x u7s-etcd.target
[Unit]
Description=Usernetes target for etcd
Requires=u7s-etcd.service
After=u7s-etcd.service
PartOf=u7s-master-with-etcd.target
EOF

cat <<EOF | x u7s-etcd.service
[Unit]
Description=Usernetes etcd service
BindsTo=u7s-rootlesskit.service
PartOf=u7s-etcd.target

[Service]
Type=notify
NotifyAccess=all
ExecStart=${base}/boot/etcd.sh
ExecStartPost=${base}/boot/etcd-init-data.sh
${service_common}
EOF

### master
# TODO: support running without RootlessKit
# TODO: decouple from etcd (for supporting etcd on another node)
cat <<EOF | x u7s-master.target
[Unit]
Description=Usernetes target for Kubernetes master components
Requires=u7s-kube-apiserver.service u7s-kube-controller-manager.service u7s-kube-scheduler.service
After=u7s-kube-apiserver.service u7s-kube-controller-manager.service u7s-kube-scheduler.service
PartOf=u7s-master-with-etcd.target

[Install]
WantedBy=u7s-master-with-etcd.target
EOF

cat <<EOF | x u7s-kube-apiserver.service
[Unit]
Description=Usernetes kube-apiserver service
BindsTo=u7s-rootlesskit.service
Requires=u7s-etcd.service
After=u7s-etcd.service
PartOf=u7s-master.target

[Service]
Type=notify
NotifyAccess=all
ExecStart=${base}/boot/kube-apiserver.sh
${service_common}
EOF

cat <<EOF | x u7s-kube-controller-manager.service
[Unit]
Description=Usernetes kube-controller-manager service
BindsTo=u7s-rootlesskit.service
Requires=u7s-kube-apiserver.service
After=u7s-kube-apiserver.service
PartOf=u7s-master.target

[Service]
ExecStart=${base}/boot/kube-controller-manager.sh
${service_common}
EOF

cat <<EOF | x u7s-kube-scheduler.service
[Unit]
Description=Usernetes kube-scheduler service
BindsTo=u7s-rootlesskit.service
Requires=u7s-kube-apiserver.service
After=u7s-kube-apiserver.service
PartOf=u7s-master.target

[Service]
ExecStart=${base}/boot/kube-scheduler.sh
${service_common}
EOF

### node
if [ -n "$cri" ]; then
	cat <<EOF | x u7s-node.target
[Unit]
Description=Usernetes target for Kubernetes node components (${cri})
Requires=u7s-${cri}.service $([ "$cri" = "containerd" ] && echo u7s-containerd-fuse-overlayfs-grpc.service) u7s-kubelet-${cri}.service u7s-kube-proxy.service $([ "$cni" = "flannel" ] && echo u7s-flanneld.service)
After=u7s-${cri}.service u7s-kubelet-${cri}.service $([ "$cri" = "containerd" ] && echo u7s-containerd-fuse-overlayfs-grpc.service) u7s-kube-proxy.service $([ "$cni" = "flannel" ] && echo u7s-flanneld.service)
PartOf=u7s.target

[Install]
WantedBy=u7s.target
EOF

	cat <<EOF | x u7s-${cri}.service
[Unit]
Description=Usernetes ${cri} service
BindsTo=u7s-rootlesskit.service
PartOf=u7s-node.target

[Service]
# containerd doesn't support NOTIFY_SOCKET yet (containerd#4043)
ExecStart=${base}/boot/${cri}.sh
${service_common}
EOF

	if [ "$cri" = "containerd" ]; then
		cat <<EOF | x u7s-containerd-fuse-overlayfs-grpc.service
[Unit]
Description=Usernetes containerd-fuse-overlayfs-grpc service
BindsTo=u7s-rootlesskit.service
PartOf=u7s-node.target
Before=u7s-containerd.service

[Service]
ExecStart=${base}/boot/containerd-fuse-overlayfs-grpc.sh
${service_common}
EOF

	fi

	cat <<EOF | x u7s-kubelet-${cri}.service
[Unit]
Description=Usernetes kubelet service (${cri})
BindsTo=u7s-rootlesskit.service
Requires=u7s-${cri}.service
After=u7s-${cri}.service
PartOf=u7s-node.target

[Service]
Type=notify
NotifyAccess=all
ExecStart=${base}/boot/kubelet-${cri}.sh
${service_common}
EOF

	cat <<EOF | x u7s-kube-proxy.service
[Unit]
Description=Usernetes kube-proxy service
BindsTo=u7s-rootlesskit.service
Requires=u7s-kubelet-${cri}.service
After=u7s-kubelet-${cri}.service
PartOf=u7s-node.target

[Service]
ExecStart=${base}/boot/kube-proxy.sh
${service_common}
EOF

	if [ "$cni" = "flannel" ]; then
		cat <<EOF | x u7s-flanneld.service
[Unit]
Description=Usernetes flanneld service
BindsTo=u7s-rootlesskit.service
PartOf=u7s-node.target

[Service]
ExecStart=${base}/boot/flanneld.sh
${service_common}
EOF
	fi
fi

### Finish installation
systemctl --user daemon-reload
if [ -z $start ]; then
	INFO 'Run `systemctl --user -T start u7s.target` to start Usernetes.'
	exit 0
fi
INFO "Starting $start"
set -x
systemctl --user -T enable $start
time systemctl --user -T start $start
systemctl --user --all --no-pager list-units 'u7s-*'
set +x
INFO 'Hint: `sudo loginctl enable-linger` to start user services automatically on the system start up.'
