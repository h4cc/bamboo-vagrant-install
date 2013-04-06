define append_if_no_such_line($file, $line, $refreshonly = 'false') {
   exec { "/bin/echo '$line' >> '$file'":
      unless      => "/bin/grep -Fxqe '$line' '$file'",
      path        => "/bin",
      refreshonly => $refreshonly,
   }
}

class must-have {
  include apt
  apt::ppa { "ppa:webupd8team/java": }

  $bamboo_home = "/vagrant/bamboo-home"
  $bamboo_version = "4.4.5"

  exec { 'apt-get update':
    command => '/usr/bin/apt-get update',
    before => Apt::Ppa["ppa:webupd8team/java"],
  }

  exec { 'apt-get update 2':
    command => '/usr/bin/apt-get update',
    require => [ Apt::Ppa["ppa:webupd8team/java"], Package["git-core"] ],
  }

  package { ["vim",
             "curl",
             "git-core",
             "bash"]:
    ensure => present,
    require => Exec["apt-get update"],
    before => Apt::Ppa["ppa:webupd8team/java"],
  }

  package { ["oracle-java7-installer"]:
    ensure => present,
    require => Exec["apt-get update 2"],
  }

  file { "bamboo.properties":
    path => "/vagrant/atlassian-bamboo-${bamboo_version}/webapp/WEB-INF/classes/bamboo-init.properties",
    content => "bamboo.home=${bamboo_home}",
    require => Exec["create_bamboo_home"],
  }

  exec {
    "accept_license":
    command => "echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections && echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections",
    cwd => "/home/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Package["curl"],
    before => Package["oracle-java7-installer"],
    logoutput => true,
  }

  exec {
    "download_bamboo":
    command => "curl -L http://www.atlassian.com/software/bamboo/downloads/binary/atlassian-bamboo-${bamboo_version}.tar.gz | tar zx",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Exec["accept_license"],
    logoutput => true,
    creates => "/vagrant/atlassian-bamboo-${bamboo_version}",
  }

  exec {
    "create_bamboo_home":
    command => "mkdir -p ${bamboo_home}",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Exec["download_bamboo"],
    logoutput => true,
    creates => "${bamboo_home}",
  }

  exec {
    "start_bamboo_in_background":
    environment => "BAMBOO_HOME=${bamboo_home}",
    command => "/vagrant/atlassian-bamboo-${bamboo_version}/bamboo.sh start &",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => [ Package["oracle-java7-installer"],
                 Exec["accept_license"],
                 Exec["download_bamboo"],
                 Exec["create_bamboo_home"] ],
    logoutput => true,
  }

  append_if_no_such_line { motd:
    file => "/etc/motd",
    line => "Run Bamboo with: BAMBOO_HOME=${bamboo_home} /vagrant/atlassian-bamboo-${bamboo_version}/bamboo.sh",
    require => Exec["start_bamboo_in_background"],
  }
}

include must-have