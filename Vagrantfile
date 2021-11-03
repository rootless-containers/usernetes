# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "fedora/35-cloud-base"
  memory = 4096
  cpus = 2
  config.vm.provider :virtualbox do |v|
    v.memory = memory
    v.cpus = cpus
  end
  config.vm.provider :libvirt do |v|
    v.memory = memory
    v.cpus = cpus
  end
  config.vm.provision "shell", inline: <<-SHELL
    set -eux -o pipefail
    dnf install -y iptables jq time

    # Delegate cgroup v2 controllers
    mkdir -p /etc/systemd/system/user@.service.d
    cp /vagrant/hack/etc_systemd_system_user@.service.d_delegate.conf /etc/systemd/system/user@.service.d/delegate.conf
    systemctl daemon-reload

    # Load kernel modules
    cat <<EOF >/etc/modules-load.d/usernetes.conf
fuse
tun
tap
bridge
veth
ip_tables
ip6_tables
iptable_nat
ip6table_nat
iptable_filter
ip6table_filter
nf_tables
x_tables
xt_MASQUERADE
xt_addrtype
xt_comment
xt_conntrack
xt_mark
xt_multiport
xt_nat
xt_tcpudp
EOF
    systemctl restart systemd-modules-load.service

    # dmesg_restrict=1 is set for testing issue 204.
    # This sysctl is NOT a requirement ro run Usernetes.
    echo "kernel.dmesg_restrict=1" > /etc/sysctl.d/99-usernetes.conf
    sysctl --system
  SHELL
end
