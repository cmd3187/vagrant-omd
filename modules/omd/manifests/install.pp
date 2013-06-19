class omd::install {

   # Relationships
   #Package['wget'] -> Notify['dl_omd_start'] -> Exec['dl_omd'] -> Notify['dl_omd_end'] -> Package['omd']
   #Package['wget'] -> Exec['dl_omd'] -> Package['omd']
   Class['epel'] -> Yumrepo['omdrepo'] -> Package['omd']

   #package {'wget':
   #   ensure => installed,
   #}

   # Download OMD
   #exec { 'dl_omd':
   #   command => 'wget --progress=dot "http://files.omdistro.org/releases/centos_rhel/omd-1.00-rh61-30.x86_64.rpm"',
   #   cwd => "/tmp",
   #   path => ['/bin', '/usr/bin', '/usr/local/bin'],
   #   creates => "/tmp/omd-1.00-rh61-30.x86_64.rpm",
   #   timeout => 0,
   #}

   yumrepo { 'omdrepo':
      descr => 'omdrepo',
      baseurl => 'http://labs.consol.de/OMD/rh6/stable/$basearch',
      enabled => 1,
      gpgcheck => 0,
      gpgkey => 'http://labs.consol.de/OMD/RPM-GPG-KEY'
   }

   # Install OMD
   package { 'omd':
      name => 'omd-1.00-rh61-30',
      ensure => installed,
   }
}
