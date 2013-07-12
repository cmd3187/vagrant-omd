# Class: omd::site
# Description: Class to provision new sites and manage their configurations
# apache: { own | none }
# core: { nagios | icinga | none }
# gearmand: { true | false }
# master: "localhost:4730"
# gearmand_neb: { true | false }
# gearman_worker: { true | false }
# mod_gearman: { true | false }
# pnp4nag: { on | gearman } - Defines how to handle check_results data. Pollers should be set to gearman!
# masters : [ ] - List of collectors. Will automatically include the master address!
define omd::site($site = $title, 
   $apache = 'own',
   $core = 'nagios',
   $gearmand = false,
   $master = "localhost:4730",
   $gearman_neb = false,
   $gearman_worker = false,
   $mod_gearman = false,
   $pnp4nag = "on",
   $hostgroups = [],
   $masters = [],
   $password = 'should_be_changed',
   $version = "1.00") {

   # check_mk User Variables
   $env_vars = [
      "OMD_SITE=${site}",
      "OMD_ROOT=/omd/sites/${site}",
      "LD_LIBRARY_PATH=\$OMD_ROOT/local/lib:\$OMD_ROOT/lib",
      "PERL5LIB=\$OMD_ROOT/local/lib/perl5/lib/perl5:\$OMD_ROOT/lib/perl5/lib/perl5:\$PERL5LIB",
      "MODULEBUILDRC=\$OMD_ROOT/.modulebuildrc",
      "PERL_MM_OPT=INSTALL_BASE=\$OMD_ROOT/local/lib/perl5/",
      "MANPATH=\$OMD_ROOT/share/man:\$MANPATH",
      "PYTHONPATH=\"$OMD_ROOT/lib/python:\$OMD_ROOT/local/lib/python",
      "MAILRC=\$OMD_ROOT/etc/mail.rc",
      "USER=$site",
      "USERNAME=$site",
      "HOME=/omd/sites/$site",
      "LOGNAME=test",
   ]

   # Gearman config options
   $config_gearman = $gearmand ? {
      false => 'off',
      true  => 'on',
      default => 'off',
   }
   $config_gearman_neb = $gearman_neb ? {
      false => 'off',
      true  => 'on',
      default => 'off',
   }
   $config_gearman_worker = $gearman_worker ? {
      false => 'off',
      true  => 'on',
      default => 'off',
   }
   $config_mod_gearman = $mod_gearman ? {
      false => 'off',
      true  => 'on',
      default => 'off',
   }

   # Relationships
   Class['omd::install'] -> Exec["omd-${site}-create"] -> File["${site}.conf"] -> File["${site}-nagios-config-link"] -> Exec["omd-${site}-start"]
   Class['omd::install'] -> File["${site}.conf"] ~> Exec["omd-${site}-force-apply"]
   Class['omd::install'] -> Exec["omd-${site}-create"] -> File["${site}-worker.conf"] ~> Service["omd"]
   Class['omd::install'] -> Exec["omd-${site}-create"] -> File["${site}-server.conf"] ~> Service["omd"]
   Class['omd::install'] -> Exec["omd-${site}-create"] -> File["${site}-nagios-config-perms"] -> File["${site}-nagios-hostgroup-dir"] -> File["${site}-nagios-host-dir"]

   # Creation scripts
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

   # OMD Configs
   file { "${site}.conf":
      content => template("omd/site.conf.erb"),
      path => "/omd/sites/${site}/etc/omd/site.conf",
      owner => "${site}", 
   }

   exex { "omd-${site}-force-apply":
      command     => "awk 'BEGIN { FS="="; print \"omd stop\"; } /CONFIG_/ { print \"omd config set\", substr(\$1, 8), \$2; } END { print \"omd start\" }' etc/omd/site.conf | bash",
      user        => $site,
      path        => ["/omd/sites/${site}/lib/perl5/bin",
         "/omd/sites/${site}/local/bin",
         "/omd/sites/${site}/bin",
         "/omd/sites/${site}/local/lib/perl5/bin",
         "/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin"],
      environment => $env_vars,
      refreshonly => true,
   }

   # mod-gearman configs
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
   
   # Nagios/Icigna Settings
   file {"${site}-nagios-config-perms":
      path => "/opt/omd/sites/${site}/etc/nagios/conf.d",
      ensure => directory,
      owner => test,
   }
   
   file {"${site}-nagios-config-link":
      target => "/opt/omd/sites/${site}/etc/nagios/conf.d",
      ensure => link,
      path => "/opt/omd/sites/${site}/etc/icinga/conf.d",
      owner => test,
   }
   
   file {"${site}-nagios-host-dir":
      path => "/opt/omd/sites/${site}/etc/nagios/conf.d/hosts",
      ensure => directory,
      owner => test,
      recurse => true,
   }

   file {"${site}-nagios-hostgroup-dir":
      path    => "/opt/omd/sites/${site}/etc/nagios/conf.d/hostgroups",
      ensure  => directory,
      owner   => test,
      recurse => true,
   }

   exec {"set-${site}-conf-permission":
      command => "chown -R ${site}:${site} /opt/omd/sites/${site}/etc/nagios/conf.d",
      path    => ["/omd/sites/${site}/lib/perl5/bin",
         "/omd/sites/${site}/local/bin",
         "/omd/sites/${site}/bin",
         "/omd/sites/${site}/local/lib/perl5/bin",
         "/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin"],
      refreshonly => true,
   }

   Nagios_hostgroup <<| |>> {
      require => [File["${site}-nagios-config-perms"],
         File["${site}-nagios-config-link"],
         File["${site}-nagios-hostgroup-dir"]],
      notify => [Exec["set-${site}-conf-permission"], Service["omd"]],
   }

   Nagios_host <<| tag == "watch" |>> {
      require => [File["${site}-nagios-config-perms"],
        File["${site}-nagios-config-link"],
        File["${site}-nagios-host-dir"]],
      notify => [Exec["set-${site}-conf-permission"], Service["omd"]],
   }

   Nagios_service <<| tag == "watch" |>> {
      require => [File["${site}-nagios-config-perms"],
         File["${site}-nagios-config-link"],
         File["${site}-nagios-host-dir"]],
      notify => [Exec["set-${site}-conf-permission"], Service["omd"]],
   }

   # Check_MK Settings
   # TODO: Make the config add in the patched version of the code
   #File["${site}-main.mk"] -> File<<| tag == "cmk_host" |>> -> Exec["${site}-check_mk-precompile"] -> Exec["${site}-check_mk-gen-services"]
   #Exec["omd-${site}-create"] -> Exec["python-gearman-${site}"] -> Exec["python-pycrypto-${site}"] -> File["check_mk-${version}-patch"] -> File["check_mk_base-${version}-patch"] -> File["${site}-main.mk"] -> Exec["${site}-check_mk-precompile"] -> Exec["${site}-check_mk-gen-services"]

   # Gearman Patch dependecies
   Exec["python-gearman"] -> File["check_mk-${version}-patch"] -> File["check_mk_base-${version}-patch"]
   Exec["python-pycrypto"] -> File["check_mk-${version}-patch"] -> File["check_mk_base-${version}-patch"]
   Exec["omd-${site}-create"] -> File["check_mk-${version}-patch"] -> File["check_mk_base-${version}-patch"]
   
   # Configs
   File["check_mk-${version}-patch"] -> File["${site}-main.mk"]
   File["check_mk_base-${version}-patch"] -> File["${site}-main.mk"]
   File["${site}-main.mk"] ~> Exec["${site}-check_mk-precompile"] ~> Exec["${site}-check_mk-gen-services"] ~> Service["omd"]

   # Gearman Patched version of the check_mk package, install easy_install, python-devel, python-setuptools
   file { "check_mk-${version}-patch":
      ensure  => present,
      source  => "puppet:///modules/omd/check_mk/${version}/check_mk.py",
      path    => "/opt/omd/versions/${version}/share/check_mk/modules/check_mk.py",
      owner   => "root",
      group   => "root",
      mode    => 0755,
   }

   # Gearman Patched version of che check_mk package, install easy_install, python-devel, python-setuptools
   file { "check_mk_base-${version}-patch":
      ensure  => present,
      source  => "puppet:///modules/omd/check_mk/${version}/check_mk_base.py",
      path    => "/opt/omd/versions/${version}/share/check_mk/modules/check_mk_base.py",
      owner   => "root",
      group   => "root",
      mode    => 0755,
   }

   # cmk config file. Includes all_hosts, which list all hosts to be processed by this server
   file { "${site}-main.mk":
      content => template('omd/main.mk.erb'),
      path    => "/opt/omd/sites/${site}/etc/check_mk/main.mk",
      owner   => $site,
      group   => $site,
   }

   # Build a single tag checking variable
   $cmk_host_tags = split(inline_template("<%= (hostgroups).join(',') %>,cmk_host"),',')

   File <<| tag == "cmk_host" |>> {
      owner   => $site,
      group   => $site,
      before  => File["${site}-main.mk"],
      require => Exec["omd-${site}-create"],
      notify  => Exec["${site}-check_mk-precompile"],
   }

   exec { "${site}-check_mk-precompile":
      command  => "check_mk -I &> /tmp/check_mk_error.txt",
      user     => $site,
      path     => ["/omd/sites/${site}/lib/perl5/bin",
         "/omd/sites/${site}/local/bin",
         "/omd/sites/${site}/bin",
         "/omd/sites/${site}/local/lib/perl5/bin",
         "/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin"],
      environment => $env_vars,
      refreshonly => true,
   }

   exec { "${site}-check_mk-gen-services":
      command => "check_mk -U",
      user    => $site,
      path    => ["/omd/sites/${site}/lib/perl5/bin",
         "/omd/sites/${site}/local/bin",
         "/omd/sites/${site}/bin",
         "/omd/sites/${site}/local/lib/perl5/bin",
         "/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin"],
      environment => $env_vars,
      refreshonly => true,
   }
      
}
