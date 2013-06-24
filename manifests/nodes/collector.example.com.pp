node 'collector.example.com' {
   class {'icingaservers':
      hostgroups => ['linux', 'site1'],
   }

   omd::site{ 'test':
      core           => 'icinga',
      gearmand       => true,
      master         => "${ipaddress_eth1}:4730",
      gearman_neb    => true,
      mod_gearman    => true,
      gearman_worker => false,
      password       => 'common_password',
   }
   
}

