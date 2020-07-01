# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "fedora/32-cloud-base"
  config.vm.provider :virtualbox do |v|
    v.memory = 2048
    v.cpus = 2
  end
  config.vm.provider :libvirt do |v|
    v.memory = 2048
    v.cpus = 2
  end
  config.vm.provision "shell", inline: <<-SHELL
    dnf install -y iptables jq

    # Delegate cgroup v2 controllers
    mkdir -p /etc/systemd/system/user@.service.d
    cat > /etc/systemd/system/user@.service.d/delegate.conf << EOF
[Service]
# default: Delegate=pids memory
# NOTE: delegation of cpuset requires systemd >= 244 (Fedora >= 32, Ubuntu >= 20.04). cpuset is ignored on Fedora 31.
Delegate=cpu cpuset io memory pids
EOF
    systemctl daemon-reload

  SHELL
end
