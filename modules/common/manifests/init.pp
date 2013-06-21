class common {
   include iptables

   host { "localhost":
      ensure => present,
      host_aliases => ['localhost', 'localhost.localdomain', 'localhost4', 'localhost4.localdomain4'],
      ip => "127.0.0.1",
   }
   host { "collector.example.com":
      ensure => present,
      host_aliases => ['collector'],
      ip => "192.168.56.100",
   }
   host { "poller1.example.com":
      ensure => present,
      host_aliases => ['poller1'],
      ip => "192.168.56.101",
   }
   host { "poller2.example.com":
      ensure => present,
      host_aliases => ['poller2'],
      ip => "192.168.56.102",
   }
   host { "puppet.exmaple.com":
      ensure => present,
      host_aliases => ['puppet'],
      ip => "192.168.56.200"
   }

   yumrepo { 'epel':
      descr => 'Extra Packages for Enterprise Linux 6 - $basearch',
      mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch',
      failovermethod => 'priority',
      enabled => 1,
      gpgcheck => 0,
      gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
   }
}

