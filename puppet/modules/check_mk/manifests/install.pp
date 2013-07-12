class check_mk::install { 

   Package["check-mk-agent"] ~> Service["xinetd"]

   package { "check-mk-agent":
      ensure => installed,
   }
}
