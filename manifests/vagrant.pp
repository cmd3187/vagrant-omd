node 'common' {
   include iptables

   host { "localhost":
      ensure => present,
      host_aliases => ['localhost', 'localhost.localdomain', 'localhost4', 'localhost4.localdomain4'],
      ip => "127.0.0.1",
   }
   host { "collector.example.com":
      ensure => present,
      host_aliases => ['collector'],
      ip => "192.168.56.100",
   }
   host { "poller1.example.com":
      ensure => present,
      host_aliases => ['poller1'],
      ip => "192.168.56.101",
   }
   host { "poller2.example.com":
      ensure => present,
      host_aliases => ['poller2'],
      ip => "192.168.56.102",
   }
   host { "puppet.exmaple.com":
      ensure => present,
      host_aliases => ['puppet'],
      ip => "192.168.56.200"
   }

   yumrepo { 'epel':
      descr => 'Extra Packages for Enterprise Linux 6 - $basearch',
      mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch',
      failovermethod => 'priority',
      enabled => 1,
      gpgcheck => 0,
      gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
   }
}

node 'icigna_servers' inherits 'common' {
   include omd
}

node 'collector.example.com' inherits 'icinga_servers' {
   omd::site{ 'test':
      core => 'icinga',
      gearmand => true,
      gearman_worker => true,
   }

   file {"nagios-hosts":
      path => '/opt/omd/sites/test/etc/icinga/conf.d/hosts',
      ensure => directory,
      owner => test,
   }

   @@nagios_host { "collector.example.com":
      address => "192.168.56.101",
      alias => "collector",
      ensure => present,
      target => "/opt/omd/sites/test/etc/icinga/conf.d/hosts/collector.example.com.cfg",
      tag => "poller",
   }

   Nagios_host <<| tag == "poller" |>> {
      require => File['nagios-hosts'],
   }
}

node 'poller1.example.com' inherits 'icinga_servers' {
   omd::site{ 'test':
      core => 'icinga',
      gearman_worker => true,
      master => "192.168.56.100:4730",
   }

   @@nagios_host { "poller1.example.com":
      address => "192.168.56.101",
      alias => "poller1",
      ensure => present,
      target => "/opt/omd/sites/test/etc/icinga/conf.d/hosts/poller1.example.com.cfg",
      tag => "poller",
   }
}

node 'poller2.example.com' inherits 'icinga_servers' {
   omd::site{ 'test':
      core => 'icinga',
      gearman_worker => true,
      master => "192.168.56.100:4730",
   }

   @@nagios_host { "poller2.example.com":
      address => "192.168.56.102",
      alias => "poller2",
      ensure => present,
      target => "/opt/omd/sites/test/etc/icinga/conf.d/hosts/poller2.example.com.cfg",
      tag => "poller",
   }  
}

node 'puppet.example.com' inherits 'common' {
   # Dependency Tree
   Yumrepo['epel'] -> Class['puppet::server']

   class { 'puppet': puppet_server => "puppet.example.com" }  
}
