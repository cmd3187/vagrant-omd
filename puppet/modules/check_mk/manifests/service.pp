class check_mk::service {
   if !defined(Service['xinetd']) {
      service { "xinetd":
         ensure => running,
         enable => true,
      }
   }
}
