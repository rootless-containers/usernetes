#!/bin/bash
# CFSSL tool (called only via install.sh)
#
# ref: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/1.15.3/docs/04-certificate-authority.md
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

# global vars
arg0="$0"
loglevel="2"
cc="$U7S_BASE_DIR/config/cfssl"

# opts
dir=""
master=""
nodes=()

# text for --help
usage() {
	echo "Usage: ${arg0} --dir=DIR --master MASTER --node NODE0HOSTNAME,NODE0IP --node NODE1HOSTNAME,NODE1IP"
	echo "DO NOT EXECUTE THIS TOOL MANUALLY"
}

# parse CLI args
if ! args="$(getopt -o h --long help,dir:,master:,node: -n "$arg0" -- "$@")"; then
	usage
	exit 1
fi
eval set -- "$args"
while true; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--dir)
		dir="$2"
		shift 2
		;;
	--master)
		master="$2"
		shift 2
		;;
	--node)
		nodes=(${nodes[@]} "$2")
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

if [ -z "$dir" ]; then
	log::error "No dir was specified"
	exit 1
fi
mkdir -p $dir
master_d="${dir}/master"
mkdir -p ${master_d}

if [ -z "$master" ]; then
	log::error "No masterwas specified"
	exit 1
fi

# Certificate Authority
if [[ -f "${master_d}/ca.pem" ]]; then
	log::info "Already exists: ${master_d}/ca.pem"
else
	log::info "Creating ${master_d}/{ca.pem,ca-key.pem}"
	cfssl gencert -loglevel="$loglevel" -initca "$cc/ca-csr.json" | cfssljson -bare "${master_d}/ca"
fi

cfssl_gencert_master() {
	name="$1"
	if [[ -f "${master_d}/${name}.pem" ]]; then
		log::info "Already exists: ${master_d}/${name}.pem"
	else
		log::info "Creating ${master_d}/{${name}.pem,${name}-key.pem}"
		cfssl gencert -loglevel="$loglevel" \
			-ca="${master_d}/ca.pem" \
			-ca-key="${master_d}/ca-key.pem" \
			-config="$cc/ca-config.json" \
			-profile=kubernetes \
			"$cc/${name}-csr.json" | cfssljson -bare "${master_d}/${name}"
	fi
}

create_kubeconfig() {
	kubeconfig="$1"
	user="$2"
	server="$3"
	ca="$4"
	clientcert="$5"
	clientkey="$6"
	log::info "Creating $kubeconfig"
	echo >$kubeconfig
	kubectl config set-cluster kubernetes-the-hard-way \
		--certificate-authority=$ca \
		--embed-certs=true \
		--server=$server \
		--kubeconfig=$kubeconfig
	kubectl config set-credentials $user \
		--client-certificate=$clientcert \
		--client-key=$clientkey \
		--embed-certs=true \
		--kubeconfig=$kubeconfig
	kubectl config set-context default \
		--cluster=kubernetes-the-hard-way \
		--user=$user \
		--kubeconfig=$kubeconfig
	kubectl config use-context default --kubeconfig=$kubeconfig
}

# The Admin Client Certificate
cfssl_gencert_master "admin"
create_kubeconfig ${master_d}/admin-localhost.kubeconfig admin https://127.0.0.1:6443 ${master_d}/ca.pem ${master_d}/admin.pem ${master_d}/admin-key.pem
create_kubeconfig ${master_d}/admin-${master}.kubeconfig admin https://${master}:6443 ${master_d}/ca.pem ${master_d}/admin.pem ${master_d}/admin-key.pem

# The Controller Manager Client Certificate
cfssl_gencert_master "kube-controller-manager"
create_kubeconfig ${master_d}/kube-controller-manager.kubeconfig system:kube-controller-manager https://127.0.0.1:6443 ${master_d}/ca.pem ${master_d}/kube-controller-manager.pem ${master_d}/kube-controller-manager-key.pem

# The Kube Proxy Client Certificate
cfssl_gencert_master "kube-proxy"
create_kubeconfig ${master_d}/kube-proxy.kubeconfig system:kube-proxy https://${master}:6443 ${master_d}/ca.pem ${master_d}/kube-proxy.pem ${master_d}/kube-proxy-key.pem

# The Scheduler Client Certificate
cfssl_gencert_master "kube-scheduler"
create_kubeconfig ${master_d}/kube-scheduler.kubeconfig system:kube-scheduler https://127.0.0.1:6443 ${master_d}/ca.pem ${master_d}/kube-scheduler.pem ${master_d}/kube-scheduler-key.pem

# The Kubernetes API Server Certificate
if [[ -f "${master_d}/kubernetes.pem" ]]; then
	log::info "Already exists: ${master_d}/kubernetes.pem"
else
	log::info "Creating ${master_d}/{kubernetes.pem,kubernetes-key.pem}"
	k_hostnames="kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local"
	ip_addrs=$(hostname -I | sed -e 's/ /,/g' -e 's/,$//g')
	k_cluster_ip="10.0.0.1"
	cfssl gencert -loglevel="$loglevel" \
		-ca="${master_d}/ca.pem" \
		-ca-key="${master_d}/ca-key.pem" \
		-config="$cc/ca-config.json" \
		-hostname=${master},$(hostname),${ip_addrs},localhost,127.0.0.1,${k_hostnames},${k_cluster_ip} \
		-profile=kubernetes \
		"$cc/kubernetes-csr.json" | cfssljson -bare "${master_d}/kubernetes"
fi

# The Service Account Key Pair
cfssl_gencert_master "service-account"

# Nodes
for n in "${nodes[@]}"; do
	nodename=$(echo $n | sed -e 's/,.*//g')
	node_d="${dir}/nodes.${nodename}"
	mkdir -p "${node_d}"
	if [[ -f "${node_d}/master" ]]; then
		log::info "Already exists: ${node_d}/master"
	else
		log::info "Writing $master to ${node_d}/master"
		echo $master >${node_d}/master
	fi
	# The Kubelet Client Certificates
	if [[ -f "${node_d}/ca.pem" ]]; then
		log::info "Already exists: ${node_d}/ca.pem"
	else
		log::info "Copying ${master_d}/ca.pem to ${node_d}/ca.pem"
		cp -f ${master_d}/ca.pem ${node_d}/ca.pem
	fi
	if [[ -f "${node_d}/node.pem" ]]; then
		log::info "Already exists: ${node_d}/node.pem"
	else
		log::info "Creating ${node_d}/{node.pem,node-key.pem}"
		cat >${node_d}/node-csr.json <<EOF
{
  "CN": "system:node:${nodename}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
		cfssl gencert -loglevel="$loglevel" \
			-ca="${master_d}/ca.pem" \
			-ca-key="${master_d}/ca-key.pem" \
			-config="$cc/ca-config.json" \
			-hostname=$n \
			-profile=kubernetes \
			"${node_d}/node-csr.json" | cfssljson -bare "${node_d}/node"
	fi
	# The kube-proxy Kubernetes Configuration File
	log::info "Copying ${master_d}/kube-proxy.kubeconfig to ${node_d}/kube-proxy.kubeconfig"
	cp -f ${master_d}/kube-proxy.kubeconfig ${node_d}/kube-proxy.kubeconfig
	# The kubelet Kubernetes Configuration File
	create_kubeconfig ${node_d}/node.kubeconfig system:node:${nodename} https://${master}:6443 ${master_d}/ca.pem ${node_d}/node.pem ${node_d}/node-key.pem
	# DONE
	touch ${node_d}/done
done
# DONE
touch ${master_d}/done
