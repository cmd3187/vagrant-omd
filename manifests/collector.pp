include iptables
include omd

omd::config{ 'dev':
   site => "dev",
}

omd::site{ 'test':
   core => 'icinga',
   isMaster => 'true',
   slaves => ['192.168.56.101', '192.168.56.102']
}
