class check_mk::install { 

   package { "check-mk-agent":
      ensure => installed,
   }
}
