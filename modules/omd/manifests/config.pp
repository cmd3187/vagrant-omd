define omd::config($site) {
   # Relationships
   Class['omd'] -> Exec["omd-${site}-create"] -> Exec["omd-${site}-start"]	

   exec { "omd-${site}-create":		
      command => "omd create $site",
      path => ['/bin', '/usr/bin', '/usr/local/bin'],
      timeout => 0,
      unless => "omd status ${site}"
   }

   exec { "omd-${site}-start":
      command => "sudo -iu ${site} omd start",
      path => ['/bin', '/usr/bin', '/usr/local/bin'],
      timeout => 0,
      unless => "omd status ${site}"
   }
}
