# @summary Create the varlink socket for podman
#
# @param ensure
#   State of the resource must be either 'present' or 'absent'.
#
# @param socket
#   Complete path to the varlink socket file
#
# @param user
#   The owner of the varlink socket
#   
# @param group
#   The group owner of the varlink socket
#   
# @param socket_mode
#   The file permission mode of the varlink socket
#   
#
class podman::varlink (
  Enum['present', 'absent'] $ensure = 'present',
  String $socket                    = '/run/podman/io.podman',
  String $user                      = 'root',
  String $group                     = 'root',
  String $socket_mode               = '0750',
) {
  # manage service temp files with systemd
  $working_directory = join(split($socket, '/')[0:-1], ',')
  file { '/etc/tmpfiles.d/podman.conf':
    ensure   => $ensure,
    contents => "d ${working_directory} ${socket_mode} ${user} ${group}"
    owner    => 'root',
    group    => 'root'
    notify   => Exec['podman-systemd-tmpfiles-refresh'],
  }

  exec { 'podman-systemd-refresh':
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }
  exec { 'podman-systemd-tmpfiles-refresh':
      command     => 'systemd-tmpfiles --create --no-pager',
      refreshonly => true,
  }

  # install service file
  file { '/etc/systemd/system/io.podman.socket' :
    ensure   => $ensure,
    content  => @("END"),
                # FILE MANAGED BY PUPPET
                [Unit]
                Description=Podman Remote API Socket
                Documentation=man:podman-varlink(1)
                
                [Socket]
                ListenStream=${socket}
                SocketMode=${socket_mode}
                SocketUser=${user}
                SocketGroup=${group}
                
                [Install]
                WantedBy=sockets.target
                |END
    notify   => Exec['podman-systemd-refresh'],
  }

  if $ensure == 'present' {
    $svc_ensure = 'running'
  	$svc_enable = 'true'
  } else {
  	$svc_ensure = 'stopped'
  	$svc_enable = 'false'
  }

  service { 'io.podman.socket':
    ensure  => $svc_ensure,
    enable  => $svc_enable,
    require => File['/etc/systemd/system/io.podman.socket'],
  }
}
