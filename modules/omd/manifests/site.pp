# Class: omd::site
# Description: Class to provision new sites and manage their configurations
# apache: { own | none }
# core: { nagios | icinga | none }
# gearmand: { true | false }
# master: "localhost:4730"
# gearmand_neb: { true | false }
# gearman_worker: { true | false }
# mod_gearman: { true | false }
# masters : [ ] - List of collectors. Will automatically include the master address!
define omd::site($site = $title, 
   $apache = 'own',
   $core = 'nagios',
   $gearmand = false,
   $master = "localhost:4730",
   $gearman_neb = false,
   $gearman_worker = false,
   $mod_gearman = false,
   $hostgroups = [],
   $masters = [],
   $password = 'should_be_changed') {

   # Gearman config options
   $config_gearman = $gearmand ? {
      false => 'off',
      true  => 'on',
   }
   $config_gearman_neb = $gearman_neb ? {
      false => 'off',
      true  => 'on',
   }
   $config_gearman_worker = $gearman_worker ? {
      false => 'off',
      true  => 'on',
   }
   $config_mod_gearman = $mod_gearman ? {
      false => 'off',
      true  => 'on',
   }

   # Relationships
   Class['omd::install'] -> Exec["omd-${site}-create"] -> File["${site}.conf"] -> Exec["omd-${site}-start"]
   File["${site}.conf"] ~> Service["omd"]
   File["${site}-worker.conf"] ~> Service["omd"]
   File["${site}-server.conf"] ~> Service["omd"]

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

   file { "${site}-worker.conf":
      content => template("omd/worker.cnf.erb"),
      path    => "/omd/sites/${site}/etc/mod-gearman/worker.cfg",
      owner   => "${site}",
   }

   file { "${site}-server.conf":
      content => template("omd/server.cnf.erb"),
      path    => "/omd/sites/${site}/etc/mod-gearman/server.cfg",
      owner   => "${site}",
   }
}
