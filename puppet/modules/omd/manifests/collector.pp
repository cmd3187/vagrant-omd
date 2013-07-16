define omd::collector( $masters = ["${ipaddress_eth1}:4730"],
      $hostgroups = []) {
   require omd

   omd::site{ $title :
      core           => 'icinga',
      gearmand       => true,
      masters        => $masters,
      gearman_neb    => true,
      mod_gearman    => true,
      gearman_worker => false,
      pnp4nag        => 'gearman',
      password       => 'common_password',
   }

   class{ 'omd::watch':
      site_name  => $title,
      hostgroups => $hostgroups,
      tags       => ['watch', 'collector'],
      address    => $ipaddress_eth1,
   }

   # Hostgroups
   nagios_hostgroup { "site1":
      ensure => present,
      notes  => "Site 1 servers",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/site1.cfg",
   }
   nagios_hostgroup { "site2":
      ensure => present,
      notes  => "Site 2 servers",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/site2.cfg",
   }

   nagios_hostgroup { "monitoring":
      ensure => present,
      notes  => "All servers that should be monitored",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/monitoring.cfg",
   }    

   nagios_hostgroup { "linux":
      ensure => present,
      notes  => "All linux servers in the environment",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/linux.cfg",
   }

}
