class epel {  
   
   # Install EPEL Repository
   yumrepo { 'epel':
      descr => 'Extra Packages for Enterprise Linux 6 - $basearch',
      mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch',
      failovermethod => 'priority',
      enabled => 1,
      gpgcheck => 1,
      gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
      require => File['epel6-key'],
   }  
   
   yumrepo { 'epel-debuginfo':
      descr => 'Extra Packages for Enterprise Linux 6 - $basearch - Debug',
      mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-debug-6&arch=$basearch',
      failovermethod => 'priority',
      enabled => 0,
      gpgcheck => 1,
      gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
      require => File['epel6-key'],
   }  
   
   yumrepo { 'epel-source':
      descr => 'Extra Packages for Enterprise Linux 6 - $basearch - Source',
      mirrorlist => 'https://mirrors.fedoraproject.org/metalink?repo=epel-source-6&arch=$basearch',
      failovermethod => 'priority',
      enabled => 0,
      gpgcheck => 1,
      gpgkey => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
      require => File['epel6-key'],
   }  
   
   file {'epel6-key':
      path => '/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6',
      ensure => present,
      source => "puppet:///modules/omd/RPM-GPG-KEY-EPEL-6",
   }
}
