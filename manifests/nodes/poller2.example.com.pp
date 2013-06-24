node 'poller2.example.com' {
   class { "icingaservers":
      hostgroups => ['site2', 'linux'],
   }


   omd::poller{ 'test':
      master     => "collector.example.com:4730",
      hostgroups => ['site2'],
   }

   #omd::site{ 'test':
   #   apache         => 'none',
   #   core           => 'none',
   #   master         => "collector.example.com:4730",
   #   gearman_worker => true,
   #   gearman_neb    => false,
   #   mod_gearman    => true,
   #   password       => 'common_password',
   #   hostgroups     => ['site1'],
   #}
}

