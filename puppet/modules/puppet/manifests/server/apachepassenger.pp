class puppet::server::apachepassenger( ) inherits puppet::server {

	#####variables==start#####
	#####variables==end#####

	#####package==start#####
	#####package==end#####

	#####config==start#####
	#####config==end#####

	#####service==start#####
	Service["puppetmaster"]{
		enable          => false,
		ensure          => stopped,
	}

	#####service==end#####
}
