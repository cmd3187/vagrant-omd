# Store all the package prereqs here
class omd::prereq {

   Package["python-devel"] -> Exec["python-pycrypto"]
   Package["python-setuptools"] -> Exec["python-gearman"]
   Package["python-setuptools"] -> Exec["python-pycrypto"]

   package { "python-devel":
      ensure => installed,
   }

   package { "python-setuptools":
      ensure => installed,
   }

   exec { "python-gearman":
      command   => "easy_install gearman",
      path      => ["/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin"],
      logoutput => true,
      creates   => "/usr/lib/python2.6/site-packages/gearman-2.0.2-py2.6.egg"
   }

   exec { "python-pycrypto":
      command   => "easy_install pycrypto",
      path      => ["/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin"],
      logoutput => true,
      creates   => "/usr/lib/python2.6/site-packages/pycrypto-2.6-py2.6-linux-x86_64.egg"
   }

}
