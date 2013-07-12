class omd::install {

   require omd::prereq

   # Relationships
   Yumrepo['omdrepo'] -> Package['omd']

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
