include iptables
include omd

#omd::config{ 'dev':
#   site => "dev",
#}

omd::site{ 'test':
   core => 'icinga',
   isMaster => 'false',
}
