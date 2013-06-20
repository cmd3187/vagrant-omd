include iptables
include omd

omd::site{ 'test':
   core => 'icinga',
   gearmand => true,
   gearman_worker => true,
}
