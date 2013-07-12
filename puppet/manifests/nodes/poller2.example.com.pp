node 'poller2.example.com' {
   class { 'hosts': }

   omd::poller{ 'test':
      master     => "collector.example.com:4730",
      hostgroups => ['site2'],
   }
   
   # Copy over the DOT files to create graphs from
   cron { "copy-dots":
      command => "cp -rp /var/lib/puppet/state/graphs/*.dot /vagrant/docs/host_diagrams/`hostname`",
      minute  => '*/5',
   }
}

