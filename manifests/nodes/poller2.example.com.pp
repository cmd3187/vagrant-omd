node 'poller2.example.com' {
   omd::poller{ 'test':
      master     => "collector.example.com:4730",
      hostgroups => ['site2'],
   }
}

