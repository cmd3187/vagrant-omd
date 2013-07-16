node 'collector2.example.com' {
   class { 'hosts': }

   omd::collector{ 'test':
      masters    => ["${ipaddress_eth1}:4730", "192.168.56.100:4730"], 
      hostgroups => ['site2', 'linux'],
   }

   # Copy over the DOT files to create graphs from
   cron { "copy-dots":
      command => "cp -rp /var/lib/puppet/state/graphs/*.dot /vagrant/docs/host_diagrams/`hostname`",
      minute  => '*/5',
   }
}

