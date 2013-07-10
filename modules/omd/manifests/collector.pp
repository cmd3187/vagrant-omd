define omd::collector( $master = "${ipaddress_eth1}:4730",
      $hostgroups = []) {
   require omd

   omd::site{ $title :
      core           => 'icinga',
      gearmand       => true,
      master         => $master,
      gearman_neb    => true,
      mod_gearman    => true,
      gearman_worker => false,
      password       => 'common_password',
   }

   class{ 'omd::watch':
      site_name  => $title,
      hostgroups => $hostgroups,
      tags       => ['watch', 'collector'],
      address    => $ipaddress_eth1,
   }

   # Hostgroups
   nagios_hostgroup { "site1":
      ensure => present,
      notes  => "Site 1 servers",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/site1.cfg",
   }
   nagios_hostgroup { "site2":
      ensure => present,
      notes  => "Site 2 servers",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/site2.cfg",
   }

   nagios_hostgroup { "monitoring":
      ensure => present,
      notes  => "All servers that should be monitored",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/monitoring.cfg",
   }    

   nagios_hostgroup { "linux":
      ensure => present,
      notes  => "All linux servers in the environment",
      target => "/opt/omd/sites/${title}/etc/nagios/conf.d/hostgroups/linux.cfg",
   }

   # Commands
   #nagios_command { "check_mk-kernel":
   #   ensure       => present,
   #   command_name => "check_mk-kernel",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-uptime":
   #   ensure       => present,
   #   command_name => "check_mk-uptime",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-kernel.util":
   #   ensure       => present,
   #   command_name => "check_mk-kernel.util",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-df":
   #   ensure       => present,
   #   command_name => "check_mk-df",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-postfix_mailq":
   #   ensure       => present,
   #   command_name => "check_mk-postfix_mailq",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-cpu.loads":
   #   ensure       => present,
   #   command_name => "check_mk-cpu.loads",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-cpu.threads":
   #   ensure       => present,
   #   command_name => "check_mk-cpu.threads",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-diskstat":
   #   ensure       => present,
   #   command_name => "check_mk-diskstat",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-mem.used":
   #   ensure       => present,
   #   command_name => "check_mk-mem.used",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-mounts":
   #   ensure       => present,
   #   command_name => "check_mk-mounts",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

   #nagios_command { "check_mk-tcp_conn_stats":
   #   ensure       => present,
   #   command_name => "check_mk-tcp_conn_stats",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}
   
   #nagios_command { "check_mk-lnx_if":
   #   ensure       => present,
   #   command_name => "check_mk-lnx_if",
   #   command_line => "echo \"ERROR - you did an active check on this service - please disable active checks\" && exit ",
   #   target       => "/opt/omd/sites/${title}/etc/nagios/conf.d/mk_commands.cfg",
   #}

}
