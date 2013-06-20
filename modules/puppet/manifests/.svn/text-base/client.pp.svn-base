class puppet::client( $puppet_server ) inherits puppet {

	#####config==start######
	$puppet_puppet_conf_template = 	$::puppetversion ? {
		/^2./		=> "puppet/client/puppet.conf-2.6-default-template.erb",
		default		=> "puppet/client/puppet.conf-default-template.erb",
	}

	File['puppet.conf']{
		content	=> template($puppet_puppet_conf_template),
		notify	=> Service['puppet'],
	}

	file { 
		"puppet_sysconfig":
		mode    => 644,
		owner   => root,
		group   => root,
		require => Package["puppet"],
		ensure  => present,
		path    => $operatingsystem ?{
			default => "/etc/sysconfig/puppet",
		},
		content => $operatingsystem ?{
			default => template("puppet/client/puppet_sysconfig-default-template.erb"),
		},
		notify  => [Service["puppet"]],
	}
	#####config==end######

	#####service==start#####
	service { 
		"puppet":
		name		=> "puppet", 
		ensure          => running,
		enable          => true,
		hasrestart      => true,
		hasstatus       => true,
		require         => Package["puppet"],
	}

	#####service==end#####
	
}

