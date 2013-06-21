# Class: omd::site
# Description: Class to provision new sites and manage their configurations
# Core: { nagios | icinga }
# gearmand: { true | false }
# gearman_worker: { true | false }
# master: "localhost:4730"
define omd::site($site = $title, 
   $core = 'nagios',
   $gearmand = false,
   $gearman_worker = false,
   $master = "localhost:4730") {

   # Collector Gearman Config Options
   case $gearmand {
      false: {
         $config_gearmand = 'off'
         $config_gearman_neb = 'off'
         $config_mod_gearman = 'off'
      }
      true: {
         $config_gearmand = 'on'
         $config_gearman_neb = 'on'
         $config_mod_gearman = 'on'
      }
   }

   # Worker/Poller Gearman Config Options
   case $gearman_worker {
      false: {
         $config_gearman_worker = 'off'
      }
      true: {
         $config_gearman_worker = 'on'
      }
   }

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
