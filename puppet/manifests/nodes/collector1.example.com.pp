node 'collector1.example.com' {
   class { 'hosts': }

   omd::collector{ 'test':
      masters    => ["${ipaddress_eth1}:4730", "192.168.56.103:4730"], 
      hostgroups => ['site1', 'linux'],
   }

   # Copy over the DOT files to create graphs from
   cron { "copy-dots":
      command => "cp -rp /var/lib/puppet/state/graphs/*.dot /vagrant/docs/host_diagrams/`hostname`",
      minute  => '*/5',
   }
}

