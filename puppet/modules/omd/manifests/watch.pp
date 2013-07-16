# Omd::Watch - Host Watcher class
# Use this class for any server/service that you would like to monitor.
# Parameters:
#  site_name: OPTIONAL - Name of the OMD environment to embed the nagios checks in. DEFAULT - test
#  hostgroups: OPTIONAL - List of hostgroups to add a particular system to. This is an array. DEFAULT - []
#  tags: OPTIONAL - List of optional tags to simplify host collection/aggregation for each host. DEFAULT - ['watch', 'check_mk']
#  checks: OPTIONAL - List of manual check to be run for the specified host through check_mk. This should consist of an array 
#     of tuple with the command, warning thresholds and error thresholds. Each tuple can be represented as a CSV line. DEFAULT - []
class omd::watch($site_name='test',
    $hostgroups = [],
    $address = $ipaddress,
    $tags = ['watch', 'check_mk'],
    $checks = undef) {

   class { "check_mk": }
  
   # Nagios Host Declaration
   @@nagios_host { $fqdn:
      address            => $address,
      alias              => $hostname,
      ensure             => present,
      target             => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
      max_check_attempts => 3,
      check_command      => "check-host-alive",
      tag                => $tags,
      hostgroups         => inline_template("<%= (hostgroups).join(',') %>"),
      check_interval     => 1, # This is in minutes!
      require            => [ Nagios_hostgroup['linux'],
         Nagios_hostgroup['monitoring'],
         Nagios_hostgroup['site1'],
         Nagios_hostgroup['site2'],],
   }

   # Check_MK Host Initialization
   @@file { "${fqdn}-cmk-config":
      path    => "/opt/omd/sites/${site_name}/etc/check_mk/conf.d/${fqdn}.mk",
      content => template("omd/mk_host.mk.erb"),
      tag     => split(inline_template("<%= (hostgroups).join(',') %>,cmk_host"),','),
   }

   # MK_Livestatus Service Checks - Linux (DERECATED IN FAVOR OF MANUALLY RUNNING "check_mk -I && check_mk -C" for all "check_mk" tagged hosts
   ## Active
   #@@nagios_service { "${fqdn}-check_mk-active":
   #   use                 => "check_mk_active",
   #   host_name           => $fqdn,
   #   service_description => "Check_MK",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   ## Passive - Performance
   #@@nagios_service { "${fqdn}-check_mk-cpu.loads":
   #   host_name           => $fqdn,
   #   service_description => "CPU load",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-cpu.loads",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",  
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk-cpu.threads":
   #   host_name           => $fqdn,
   #   service_description => "Number of threads",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-cpu.threads",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk_df_root":
   #   host_name           => $fqdn,
   #   service_description => "fs_/",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-df",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk_df_boot":
   #   host_name           => $fqdn,
   #   service_description => "fs_/boot",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-df",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk_diskstat":
   #   host_name           => $fqdn,
   #   service_description => "Disk IO Summary",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-diskstat",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk_kernel_switches":
   #   host_name           => $fqdn,
   #   service_description => "Kernel Context Switches",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-kernel",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk_kernel_pagefault":
   #   host_name           => $fqdn,
   #   service_description => "Kernel Major Page Faults",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-kernel",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   #@@nagios_service { "${fqdn}-check_mk_kernel_processes":
   #   host_name           => $fqdn,
   #   service_description => "Kernel Process Creations",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-kernel",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}
   
   #@@nagios_service { "${fqdn}-check_mk_kernel_cpu":
   #   host_name           => $fqdn,
   #   service_description => "CPU utilization",
   #   use                 => "check_mk_passive_perf",
   #   check_command       => "check_mk-diskstat",
   #   target              => "/opt/omd/sites/${site_name}/etc/nagios/conf.d/hosts/${fqdn}.cfg",
   #   tag                 => $tags,
   #}

   ## Passive - Service Availablitiy
}
