class icingaservers inherits common {
   include omd

   # Hostgroups
   nagios_hostgroup { "monitoring":
      ensure => present,
      notes  => "All servers that should be monitored",
      target => "/opt/omd/sites/test/etc/nagios/conf.d/hostgroups/monitoring.cfg",
   }    

   nagios_hostgroup { "linux":
      ensure => present,
      notes  => "All linux servers in the environment",
      target => "/opt/omd/sites/test/etc/nagios/conf.d/hostgroups/linux.cfg",
   } 
 
   # Services
   

   # Nagios Host Declaration
   @@nagios_host { $fqdn:
      address            => $ipaddress_eth1,
      alias              => $hostname,
      ensure             => present,
      target             => "/opt/omd/sites/test/etc/nagios/conf.d/hosts/${fqdn}.cfg",
      max_check_attempts => 3,
      check_command      => "check-host-alive",
      tag                => ["poller", "watch"],
      hostgroups         => ["monitoring", "linux"],
      check_interval     => 1, # This is in minutes!
      require            => [ Nagios_hostgroup['monitoring'], Nagios_hostgroup['linux']],
   }
   
   file {"nagios-config-perms":
      path => '/opt/omd/sites/test/etc/nagios/conf.d',
      ensure => directory,
      owner => test,
   }
   
   file {"nagios-config-link":
      target => '/opt/omd/sites/test/etc/nagios/conf.d',
      ensure => link,
      path => '/opt/omd/sites/test/etc/icinga/conf.d',
      owner => test,
   }
   
   file {"nagios-host-dir":
      path => '/opt/omd/sites/test/etc/nagios/conf.d/hosts',
      ensure => directory,
      owner => test,
      recurse => true,
   }

   file {"nagios-hostgroup-dir":
      path    => '/opt/omd/sites/test/etc/nagios/conf.d/hostgroups',
      ensure  => directory,
      owner   => test,
      recurse => true,
   }

   Nagios_hostgroup <<| |>> {
      require => [File['nagios-config-perms'],
         File['nagios-config-link']],
      notify => Service["omd"],
      before => File["nagios-host-dir"],
   }

   Nagios_host <<| tag == "watch" |>> {
      require => [File['nagios-config-perms'],
	      File['nagios-config-link']],
      notify => Service["omd"],
      before => File["nagios-host-dir"],
   }
}

