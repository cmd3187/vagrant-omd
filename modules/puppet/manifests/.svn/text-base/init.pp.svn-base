#Class: puppet
# Requires:

class puppet( $puppet_server = '' ){

	#####variables==start#####
	$puppet_user	= "puppet"
	$puppet_group	= "puppet"
	#####variables==end#####

	#####package==start#####
	package {
		puppet:
		name => $::os_osfamily ? {
			default => "puppet",
		},
		ensure => present,
	}
	#####package==end#####


	#####config==start#####
	file { 
		"puppet.conf":
		mode 	=> 644,
		owner	=> root,
		group 	=> root,
		ensure 	=> present,
		path 	=> $operatingsystem ?{
			default => "/etc/puppet/puppet.conf",
		},
		require	=> Package['puppet'],
	}

	#####config==end#####

	case $::fqdn {
		"$puppet_server":	{ class {'puppet::server': puppet_server => $puppet_server } }
		default:		{ class {'puppet::client': puppet_server => $puppet_server } }
	}


}
