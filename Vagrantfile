# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Puppet Provisioner
  config.vm.define :puppet do |puppet|
    puppet.vm.box = "centos-63-x64"
    puppet.vm.network :private_network, ip: "192.168.56.200"
    puppet.vm.hostname = "puppet.example.com"
    puppet.vm.provider "virtualbox" do |v|
      v.customize ['modifyvm', :id, '--nictype1', 'virtio']
      v.customize ['modifyvm', :id, '--nictype2', 'virtio']
    end
    puppet.vm.provision :puppet do |pd|
     pd.manifests_path = "puppet/manifests"
     pd.module_path = "puppet/modules"
     pd.manifest_file = "puppet-epel.pp"
    end
    puppet.vm.provision :puppet do |pd|
     pd.manifests_path = "puppet/manifests"
     pd.module_path = "puppet/modules"
     pd.manifest_file = "nodes/puppet.example.com.pp"
    end
  end

  # Core Environment
  config.vm.define :collector1 do |collector1|
    collector1.vm.box = "centos-63-x64"
    collector1.vm.network :forwarded_port, guest: 80, host: 8080
    collector1.vm.network :private_network, ip: "192.168.56.100"
    collector1.vm.hostname = "collector1.example.com"
    collector1.vm.provider "virtualbox" do |v|
      v.customize ['modifyvm', :id, '--nictype1', 'virtio']
      v.customize ['modifyvm', :id, '--nictype2', 'virtio']
    end
    collector1.vm.provision :puppet do |puppet|
      puppet.manifests_path = "puppet/manifests"
      puppet.module_path = "puppet/modules"
      puppet.manifest_file = "puppet-epel.pp"
    end
    collector1.vm.provision :puppet_server do |puppet|
      puppet.puppet_server = "puppet.example.com"
      puppet.options = "--verbose"
    end
  end

  config.vm.define :collector2 do |collector2|
    collector2.vm.box = "centos-63-x64"
    collector2.vm.network :forwarded_port, guest: 80, host: 8080
    collector2.vm.network :private_network, ip: "192.168.56.103"
    collector2.vm.hostname = "collector2.example.com"
    collector2.vm.provider "virtualbox" do |v|
      v.customize ['modifyvm', :id, '--nictype1', 'virtio']
      v.customize ['modifyvm', :id, '--nictype2', 'virtio']
    end
    collector2.vm.provision :puppet do |puppet|
      puppet.manifests_path = "puppet/manifests"
      puppet.module_path = "puppet/modules"
      puppet.manifest_file = "puppet-epel.pp"
    end
    collector2.vm.provision :puppet_server do |puppet|
      puppet.puppet_server = "puppet.example.com"
      puppet.options = "--verbose"
    end
  end

  config.vm.define :poller1 do |poller1|
    poller1.vm.box = "centos-63-x64"
    poller1.vm.network :forwarded_port, guest: 80, host: 2201
    poller1.vm.network :private_network, ip: "192.168.56.101"
    poller1.vm.hostname = "poller1.example.com"
    poller1.vm.provider "virtualbox" do |v|
      #v.name = "poller1.example.com"
      v.customize ['modifyvm', :id, '--nictype1', 'virtio']
      v.customize ['modifyvm', :id, '--nictype2', 'virtio']
    end
    #poller1.vm.provision :shell do |shell|
    #  shell.inline = "echo '192.168.56.200 puppet.example.com puppet' >> /etc/hosts"
    #end
    poller1.vm.provision :puppet do |puppet|
      puppet.manifests_path = "puppet/manifests"
      puppet.module_path = "puppet/modules"
      puppet.manifest_file = "puppet-epel.pp"
    end
    poller1.vm.provision :puppet_server do |puppet|
      puppet.puppet_server = "puppet.example.com"
      puppet.options = "--verbose"
    end
    #poller1.vm.provision :puppet do |puppet|
    #  puppet.manifests_path = "manifests"
    #  puppet.module_path = "modules"
    #  puppet.manifest_file = "vagrant.pp"
    #end
  end

  config.vm.define :poller2 do |poller2|
    poller2.vm.box = "centos-63-x64"
    poller2.vm.network :forwarded_port, guest: 80, host: 2203
    poller2.vm.network :private_network, ip: "192.168.56.102"
    poller2.vm.hostname = "poller2.example.com"
    poller2.vm.provider "virtualbox" do |v|
      #v.name = "poller2.example.com"
      v.customize ['modifyvm', :id, '--nictype1', 'virtio']
      v.customize ['modifyvm', :id, '--nictype2', 'virtio']
    end
    #poller2.vm.provision :shell do |shell|
    #  shell.inline = "echo '192.168.56.200 puppet.example.com puppet' >> /etc/hosts"
    #end
    poller2.vm.provision :puppet do |puppet|
      puppet.manifests_path = "puppet/manifests"
      puppet.module_path = "puppet/modules"
      puppet.manifest_file = "puppet-epel.pp"
    end
    poller2.vm.provision :puppet_server do |puppet|
      puppet.puppet_server = "puppet.example.com"
      puppet.options = "--verbose"
    end
    #poller2.vm.provision :puppet do |puppet|
    #  puppet.manifests_path = "manifests"
    #  puppet.module_path = "modules"
    #  puppet.manifest_file = "vagrant.pp"
    #end
  end

end
