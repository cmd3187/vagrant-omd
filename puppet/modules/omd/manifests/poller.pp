define omd::poller( $masters = ["localhost:4730"],
      $hostgroups = []) {
   require omd
   $checks = ["\"omd_status\", \"${title}\", None",
      '"cpu.loads", None, (1, 2)',
   ]
   omd::site{ $title :
      apache         => 'none',
      core           => 'none',
      masters        => $masters,
      gearman_worker => true,
      gearman_neb    => false,
      mod_gearman    => true,
      pnp4nag        => "off",
      password       => 'common_password',
      hostgroups     => $hostgroups,
   }

   class{ 'omd::watch':
      site_name  => $title,
      hostgroups => $hostgroups,
      tags       => ['watch', 'poller'],
      address    => $ipaddress_eth1,
      checks     => $checks,
   }
}
