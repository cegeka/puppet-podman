# @summary Enable a given user to run rootless podman containers as a systemd user service.
#
define podman::rootless {
  ensure_resource('Loginctl_user', $name, { linger => enabled })

  # Ensure the systemd directory tree exists for user services
  ensure_resource('File', [
      "${Users::Localuser[$name]['home']}/.config",
      "${Users::Localuser[$name]['home']}/.config/containers",
      "${Users::Localuser[$name]['home']}/.config/systemd",
      "${Users::Localuser[$name]['home']}/.config/systemd/user"
    ], {
      ensure  => directory,
      owner   => $name,
      group   => "${Users::Localuser[$name]['logingroup']}",
      mode    => '0700',
      require => Users::Localuser["$name"],
    }
  )

  # Create the user directory for rootless quadlet files
  ensure_resource(
    'File', [
      '/etc/containers/systemd',
      '/etc/containers/systemd/users',
      "/etc/containers/systemd/users/${Users::Localuser[$name]['uid']}"
    ],
    { ensure  => directory }
  )

  exec { "start_${name}.slice":
    path    => $facts['path'],
    command => "machinectl shell ${name}@.host '/bin/true'",
    unless  => "systemctl is-active user-${Users::Localuser[$name]['uid']}.slice",
    require => [
      Loginctl_user[$name],
      File["${Users::Localuser[$name]['home']}/.config/systemd/user"],
    ],
  }

  if $podman::enable_api_socket {
    exec { "podman rootless api socket ${name}":
      command     => 'systemctl --user enable --now podman.socket',
      path        => $facts['path'],
      user        => $name,
      environment => [
        "HOME=${Users::Localuser[$name]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${Users::Localuser[$name]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${Users::Localuser[$name]['uid']}/bus",
      ],
      unless      => 'systemctl --user status podman.socket',
      require     => [
        Loginctl_user[$name],
        Exec["start_${name}.slice"],
      ],
    }
  }
}
