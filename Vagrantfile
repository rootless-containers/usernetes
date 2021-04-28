# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "fedora/34-cloud-base"
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
    dnf install -y iptables jq

    # Delegate cgroup v2 controllers
    mkdir -p /etc/systemd/system/user@.service.d
    cp /vagrant/hack/etc_systemd_system_user@.service.d_delegate.conf /etc/systemd/system/user@.service.d/delegate.conf
    systemctl daemon-reload

    # dmesg_restrict=1 is set for testing issue 204.
    # This sysctl is NOT a requirement ro run Usernetes.
    sysctl -w kernel.dmesg_restrict=1
  SHELL
end
