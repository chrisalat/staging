Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ] }

group {
  'puppet': ensure => 'present'
}

class init {
  
  class { 'apt':
    always_apt_update => false,
  }
  
  apt::source { 'ubuntu_precise':
    location => 'http://us.archive.ubuntu.com/ubuntu/',
    release => 'precise',
    repos => 'main restricted universe multiverse',
    include_src => true,
  }

  Exec['apt-get update'] -> Package <| |>
  
  exec { 'apt-get update':
    command => 'apt-get update',
  }
  
}

class system-services {
  
  class { 'ntp':
    ensure => running,
    servers => [ 'time.apple.com iburst', 'pool.ntp.org iburst', ],
    autoupdate => true,
  }
  
}

class system-setup {
  
  package { [ 'wget', 'nano', 'curl', 'build-essential', 'libpcre3-dev', 'imagemagick', 'openjdk-7-jre-headless' ]:
    ensure => 'installed',
    require => Exec['apt-get update'],
  }
  
}

class setup-pear {
  
  include pear
  
  exec { 'pear upgrade':
    command => '/usr/bin/pear upgrade',
    returns => [ 0, '', ' '],
    require => Package['php-pear'],
  }
  
  exec { 'pear auto_discover':
    command => '/usr/bin/pear config-set auto_discover 1',
    require => Package['php-pear'],
  }
  
  exec { 'pear update-channels':
    command => '/usr/bin/pear update-channels',
    require => Package['php-pear'],
  }
  
  exec { 'pear install phpunit':
    command => '/usr/bin/pear install --alldeps pear.phpunit.de/PHPUnit',
    creates => '/usr/bin/phpunit',
    require => Exec['pear update-channels'],
  }

  exec { 'pear install phploc':
    command => '/usr/bin/pear install --alldeps pear.phpunit.de/phploc',
    creates => '/usr/bin/phploc',
    require => Exec['pear update-channels'],
  }

  exec { 'pear install phpcpd':
    command => '/usr/bin/pear install --alldeps pear.phpunit.de/phpcpd',
    creates => '/usr/bin/phpcpd',
    require => Exec['pear update-channels'],
  }

  exec { 'pear install phpcs':
    command => '/usr/bin/pear install --alldeps PHP_CodeSniffer',
    creates => '/usr/bin/phpcs',
    require => Exec['pear update-channels'],
  }

  exec { 'pear install pdepend':
    command => '/usr/bin/pear install --alldeps pear.pdepend.org/PHP_Depend-beta',
    creates => '/usr/bin/pdepend',
    require => Exec['pear update-channels'],
  }

  exec { 'pear install phpmd':
    command => '/usr/bin/pear install --alldeps pear.phpmd.org/PHP_PMD',
    creates => '/usr/bin/phpmd',
    require => Exec['pear update-channels'],
  }

  exec { 'pear install PHP_CodeBrowser':
    command => '/usr/bin/pear install --alldeps pear.phpqatools.org/PHP_CodeBrowser',
    creates => '/usr/bin/phpcb',
    require => Exec['pear update-channels'],
  }
  
}

class setup-php {
  
  include php::fpm
  
  php::module { [ 'dev', 'curl', 'gd', 'mcrypt', 'memcached', 'mysql', 'tidy', 'imap', ]:
    notify => Class['php::fpm::service'],
  }
  
  php::module { [ 'memcache', 'xdebug', ]:
    notify => Class['php::fpm::service'],
    source => '/etc/php5/conf.d/',
  }
  
  php::module { [ 'apc', ]:
    notify => Class['php::fpm::service'],
    source => '/etc/php5/conf.d/',
    package_prefix => 'php-'
  }
  
  php::module { [ 'suhosin', ]:
    notify => Class['php::fpm::service'],
    source => '/vagrant/private/conf/php/',
  }
  
  php::conf { [ 'mysqli', 'pdo', 'pdo_mysql', ]:
    notify => Class['php::fpm::service'],
    require => Package['php-mysql'],
  }
  
  exec { 'pecl-imagick-install':
    command => 'pecl install imagick',
    unless => 'pecl info imagick',
    notify => Class['php::fpm::service'],
    require => Exec['pear update-channels'],
  }
  
  exec { 'pecl-mongo-install':
    command => 'pecl install mongo-1.2.12',
    unless => 'pecl info mongo-1.2.12',
    notify => Class['php::fpm::service'],
    require => Exec['pear update-channels'],
  }
  
  file { '/etc/php5/conf.d/application.ini':
    owner => root,
    group => root,
    mode => 664,
    source => '/vagrant/private/conf/php/application.ini',
    notify => Class['php::fpm::service'],
  }
  
  file { '/etc/php5/fpm/pool.d/www.conf':
    owner => root,
    group => root,
    mode => 664,
    source => '/vagrant/private/conf/php/php-fpm/www.conf',
    notify => Class['php::fpm::service'],
  }
  
}

class setup-nginx {
  
  class { 'nginx': }
  
  file { '/etc/nginx/conf.d/sites.conf':
    owner  => root,
    group  => root,
    mode   => 644,
    source => '/vagrant/private/conf/nginx/conf.d/sites.conf',
    require => Package['nginx'],
    notify => Service['nginx']
  }
  
  file { '/etc/nginx/sites-available/staging.local':
    owner => root,
    group => root,
    mode => 664,
    source => '/vagrant/private/conf/nginx/sites-available/staging.local',
    require => Package['nginx'],
    notify => Service['nginx'],
  }

  file { '/etc/nginx/sites-enabled/staging.local':
    owner => root,
    ensure => link,
    target => '/etc/nginx/sites-available/staging.local',
    require => Package['nginx'],
    notify => Service['nginx'],
  }
  
}

class setup-mysql {
  
  class { 'mysql': }
  
}

class system {

  include system-services
  include system-setup

}

class setup {

  Class['setup'] -> Class['system']

  include setup-pear
  include setup-php
  include setup-nginx
  include setup-mysql
  
}

require init

include system
include setup

