node 'puppet.example.com' {
   include common

   # Dependency Tree
   Yumrepo['epel'] -> Class['puppet::server']

   class { 'puppet': puppet_server => "puppet.example.com" } 

   class{ 'omd::watch':
      address    => $ipaddress_eth1,
      site_name  => 'test',
      hostgroups => ["site2", "linux"],
   }

   # Copy over the DOT files to create graphs from
   cron { "copy-dots":
      command => "cp -rp /var/lib/puppet/state/graphs/*.dot /vagrant/docs/host_diagrams/`hostname`",
      minute  => '*/5',
   }
}
