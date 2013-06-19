class omd::service {

   # Relationships
   Class['omd::install'] -> Class['omd::service']

   service { 'omd':
      enable => true,
      ensure => running,
      require => Package['omd']
   }
}
