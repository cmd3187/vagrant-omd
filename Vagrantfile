# -*- mode: ruby -*-
# vi: set ft=ruby :

$omd_install = <<SCRIPT
# Install EPEL Repo
rpm -Uvh http://mirrors.cat.pdx.edu/epel/6/i386/epel-release-6-8.noarch.rpm

# Download OMD RPM
wget --progress=dot "http://files.omdistro.org/releases/centos_rhel/omd-1.00-rh61-30.x86_64.rpm"

# Install OMD
yum -y localinstall --nogpgcheck omd-1.00-rh61-30.x86_64.rpm

# Create "Test" Instance
omd create test
sudo -iu test omd start

SCRIPT

Vagrant.configure("2") do |config|

  # Puppet Provisioner
  config.vm.define :puppet do |puppet|
    puppet.vm.box = "centos-63-x64"
    puppet.vm.network :private_network, ip: "192.168.56.200"
    puppet.vm.hostname = "puppet.example.com"
    puppet.vm.provision :puppet do |pd|
     pd.manifests_path = "manifests"
     pd.module_path = "modules"
     pd.manifest_file = "puppet.pp"
    end
  end

  # Core Environment
  config.vm.define :collector do |collector|
    collector.vm.box = "centos-63-x64"
    collector.vm.network :forwarded_port, guest: 80, host: 8080
    collector.vm.network :private_network, ip: "192.168.56.100"
    collector.vm.hostname = "collector.example.com"
    collector.vm.provider "virtualbox" do |v|
      v.name = "collector.example.com"
    end
    collector.vm.provision :puppet do |puppet|
      puppet.manifests_path = "manifests"
      puppet.module_path = "modules"
      puppet.manifest_file = "vagrant.pp"
    end
  end

  config.vm.define :poller1 do |poller1|
    poller1.vm.box = "centos-63-x64"
    poller1.vm.network :forwarded_port, guest: 80, host: 2201
    poller1.vm.network :private_network, ip: "192.168.56.101"
    poller1.vm.hostname = "poller1.example.com"
    poller1.vm.provider "virtualbox" do |v|
      v.name = "poller1.example.com"
    end
    poller1.vm.provision :puppet do |puppet|
      puppet.manifests_path = "manifests"
      puppet.module_path = "modules"
      puppet.manifest_file = "vagrant.pp"
    end
  end

  config.vm.define :poller2 do |poller2|
    poller2.vm.box = "centos-63-x64"
    poller2.vm.network :forwarded_port, guest: 80, host: 2203
    poller2.vm.network :private_network, ip: "192.168.56.102"
    poller2.vm.hostname = "poller2.example.com"
    poller2.vm.provider "virtualbox" do |v|
      v.name = "poller2.example.com"
    end
    poller2.vm.provision :puppet do |puppet|
      puppet.manifests_path = "manifests"
      puppet.module_path = "modules"
      puppet.manifest_file = "vagrant.pp"
    end
  end

end
