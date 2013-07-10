node 'collector.example.com' {
   omd::collector{ 'test': 
      hostgroups => ['site1', 'linux'],
   }
}

