class hosts { 

   @@host { $fqdn:
      ensure => present,
      host_aliases => [$hostname],
      ip => $ipaddress_eth1,
   }

   Host <<| |>> { }

}

