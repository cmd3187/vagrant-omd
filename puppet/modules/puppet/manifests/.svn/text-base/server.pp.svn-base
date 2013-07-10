class puppet::server($puppet_server='') inherits puppet{
	
	#####variables==start#####
	$puppet_rack = "/usr/share/puppet/ext/rack"
	$service_listen_port = '8140'
	$dashboard_listen_port = '3000'
	#####variables==end#####

	#####package==start######
	package {
		"puppet-server":
		name => "puppet-server",
		ensure => present
	}
	#####package==end######

	#####config==start#####
        File["puppet.conf"] {
		content	=> template('puppet/server/puppet.conf-template.erb'),
		require	+> Package['puppet-server'],
        }
	#####config==end#####
	
	#####service==start#####
	service {
		"puppetmaster":
		name            => $::os_osfamily ? {
			default => "puppetmaster",
		},
		hasrestart      => true,
		hasstatus       => true,
		require         => Package["puppet-server"],
	}
	#####service==end#####
}

