class puppet::server::puppetmaster( ) inherits puppet::server {

	#####package==start######
	#####package==end######

	#####config==start#####
        File["puppet.conf"] {
                notify  +> [Service["puppetmaster"]],
        }
	#####config==end#####

	#####service==start#####
        Service["puppetmaster"]{
                ensure          => "running",
                enable          => true,
        }
	#####service==end#####

}

