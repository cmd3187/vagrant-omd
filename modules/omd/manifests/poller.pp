define omd::poller( $master = "localhost:4730",
      $hostgroups = []) {
   require omd

   omd::site{ $title :
      apache         => 'none',
      core           => 'none',
      master         => $master,
      masters        => [$master],
      gearman_worker => true,
      gearman_neb    => false,
      mod_gearman    => true,
      pnp4nag        => "gearman",
      password       => 'common_password',
      hostgroups     => $hostgroups,
   }

   class{ 'omd::watch':
      site_name  => $title,
      hostgroups => $hostgroups,
      tags       => ['watch', 'poller'],
      address    => $ipaddress_eth1,
   }
}
