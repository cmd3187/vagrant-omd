define omd::site($site = $title, $core = 'nagios') {
   # Relationships
   Exec["omd-${site}-create"] -> Exec["omd-${site}-start"] -> File["omd-${site}.conf"]
   File["omd-${site}.conf"] ~> Service["omd"]

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

   file { "omd-${site}.conf":
      content => template("omd/site.conf.erb"),
      path => "/omd/sites/${site}/etc/omd/site.conf",
      owner => "${site}", 
   }
}
