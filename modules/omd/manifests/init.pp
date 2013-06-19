class omd {
   require epel
   include omd::install
   include omd::service
   omd::config{ 'dev':
      site => "dev",
   }
}
