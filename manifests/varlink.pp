# @summary Manage the varlink socket for podman
#
# @param ensure
#   State of the resource must be either 'present' or 'absent'.
#
# @param socket
#    Path to the podman socket file
#
# @param user
#    The owner of the socket and file
#
# @param group
#    The group owner of the socket directory and file
#
# @param socket_mode
#    permissions applied to the socket
#
define podman::varlink (
  Enum['present', 'absent'] $ensure = 'present',
  String $socket                    = '/run/podman/io.podman',
  String $user                      = 'root',
  String $group                     = 'root',
  String $socket_mode               = '0750',
) {
  require podman::install

  # Manage varlink service temp files with systemd
  $working_directory = join(split($socket, '/')[0,-2], '/')
  file { '/etc/tmpfiles.d/podman.conf':
    ensure  => $ensure,
    content => "d ${working_directory} ${socket_mode} ${user} ${group}",
    owner   => 'root',
    group   => 'root',
    notify  => Exec['podman-systemd-tmpfiles-refresh'],
  }

  exec { 'podman-systemd-refresh':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  exec { 'podman-systemd-tmpfiles-refresh':
    command     => '/usr/bin/systemd-tmpfiles --create --no-pager',
    refreshonly => true,
  }

  file { '/etc/systemd/system/io.podman.socket':
    ensure  => $ensure,
    content => @("END"),
               # FILE MANAGED BY PUPPET
               [Unit]
               Description=Podman Remote API Socket
               Documentation=man:podman-varlink(1)
               
               [Socket]
               ListenStream=${socket}
               SocketUser=${user}
               SocketGroup=${group}
               SocketMode=${socket_mode}
               
               [Install]
               WantedBy=sockets.target
               |END
    notify  => Exec['podman-systemd-refresh'],
  }

  if $ensure == 'present' {
    $svc_ensure = 'running'
    $svc_enable = true
  } else {
    $svc_ensure = 'stopped'
    $svc_enable = false
  }

  service { 'io.podman.socket':
    ensure  => $svc_ensure,
    enable  => $svc_enable,
    require => File['/etc/systemd/system/io.podman.socket'],
  }
}
