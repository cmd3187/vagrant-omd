node 'puppet.example.com' {
   include common

   class { 'hosts': }

   # Dependency Tree
   Yumrepo['epel'] -> Class['puppet::server']

   class { 'puppet': puppet_server => "puppet.example.com" } 
   #service { "puppetmaster":
   #   ensure +> true,
   #   enable +> true,
   #}

   #service { "iptables":
   #   ensure => false,
   #   enable => false,
   #}
   #service { "ip6tables":
   #   ensure => false,
   #   enable => false,
   #}

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
