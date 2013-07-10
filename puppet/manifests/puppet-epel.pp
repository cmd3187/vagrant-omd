
Yumrepo['epel'] -> Package['puppet'] -> Host['puppet.example.com']

yumrepo { 'epel':
   descr => 'Extra Packages for Enterprise Linux 6 - $basearch',
   mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch',
   failovermethod => 'priority',
   enabled => 1,
   gpgcheck => 0,
   gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
} 

package{ 'puppet':
   ensure => '2.6.18-3.el6',
}

host { "puppet.example.com":
   ensure => present,
   host_aliases => ['puppet'],
   ip => "192.168.56.200"
}
