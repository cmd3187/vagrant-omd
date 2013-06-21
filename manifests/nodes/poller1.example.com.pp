node 'poller1.example.com' {
   include icingaservers

   omd::site{ 'test':
      core => 'icinga',
      gearman_worker => true,
      master => "192.168.56.100:4730",
   }
}

