node 'collector.example.com' {
   include icingaservers

   omd::site{ 'test':
      core => 'icinga',
      gearmand => true,
      gearman_worker => true,
   }
   
}

