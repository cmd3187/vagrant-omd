node 'puppet.example.com' {
   include common

   # Dependency Tree
   Yumrepo['epel'] -> Class['puppet::server']

   class { 'puppet': puppet_server => "puppet.example.com" } 
  
   @@nagios_host { $fqdn:
      address            => $ipaddress_eth1,
      alias              => $hostname,
      ensure             => present,
      target             => "/opt/omd/sites/test/etc/nagios/conf.d/hosts/${fqdn}.cfg",
      max_check_attempts => 3,
      check_command      => "check-host-alive",
      tag                => ["watch"],
      hostgroups         => ["linux"],
      check_interval     => 1, # This is in minutes!
      require            => [ Nagios_hostgroup['monitoring'], Nagios_hostgroup['linux']],
   }
}
