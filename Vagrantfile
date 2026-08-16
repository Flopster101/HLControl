# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "gusztavvargadr/windows-server-2022-standard-core"
  config.vm.guest = :windows
  config.vm.communicator = "winrm"

  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"
  config.winrm.timeout = 1800
  config.winrm.retry_limit = 30

  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.network "forwarded_port", guest: 8080, host: 58080, auto_correct: true

  config.vm.provider :libvirt do |v|
    v.memory = 8192
    v.cpus = 4
  end

  config.vm.provision "shell", path: "packaging/windows/provision.ps1", privileged: false
end
