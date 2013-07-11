node 'collector.example.com' {
   omd::collector{ 'test': 
      hostgroups => ['site1', 'linux'],
   }

   # Copy over the DOT files to create graphs from
   cron { "copy-dots":
      command => "cp -rp /var/lib/puppet/state/graphs/*.dot /vagrant/docs/host_diagrams/`hostname`",
      minute  => '*/5',
   }
}

