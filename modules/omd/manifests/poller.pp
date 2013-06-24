define omd::poller( $master = "localhost:4730",
      $hostgroups = []) {
   omd::site{ $title :
      apache         => 'none',
      core           => 'none',
      master         => $master,
      gearman_worker => true,
      gearman_neb    => false,
      mod_gearman    => true,
      password       => 'common_password',
      hostgroups     => $hostgroups,
   }
}
