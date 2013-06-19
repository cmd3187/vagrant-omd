# Class: omd::site
# Description: Class to provision new sites and manage their configurations
define omd::site($site = $title, 
   $core = 'nagios',
   $isMaster = "true",
   $master = "",
   $slaves = []) {
   # Relationships
   Class['omd::install'] -> Exec["omd-${site}-create"] -> File["${site}.conf"] -> Exec["omd-${site}-start"]

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

   file { "${site}.conf":
      content => template("omd/site.conf.erb"),
      path => "/omd/sites/${site}/etc/omd/site.conf",
      owner => "${site}", 
   }
}
