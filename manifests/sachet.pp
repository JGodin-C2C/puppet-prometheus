# @summary This module manages prometheus sachet (https://github.com/messagebird/sachet)
# @param arch
#  Architecture (amd64 or i386)
# @param bin_dir
#  Directory where binaries are located
# @param download_extension
#  Extension for the release binary archive
# @param download_url
#  Complete URL corresponding to the where the release binary archive can be downloaded
# @param download_url_base
#  Base URL for the binary archive
# @param extra_groups
#  Extra groups to add the binary user to
# @param extra_options
#  Extra options added to the startup command
# @param group
#  Group under which the binary is running
# @param init_style
#  Service startup scripts style (e.g. rc, upstart or systemd)
# @param install_method
#  Installation method: url or package (only url is supported currently)
# @param manage_group
#  Whether to create a group for or rely on external code for that
# @param manage_service
#  Should puppet manage the service? (default true)
# @param manage_user
#  Whether to create user or rely on external code for that
# @param os
#  Operating system (linux is the only one supported)
# @param package_ensure
#  If package, then use this for package ensure default 'latest'
# @param package_name
#  The binary package name - not available yet
# @param purge_config_dir
#  Purge config files no longer generated by Puppet
# @param templates
#  An array of templates.
#  Example:
#  prometheus::sachet::templates:
#  - name: 'notifications'
#    template: |
#      {{ define "telegram_title" }}[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }} @ {{ .CommonLabels.identifier }} {{ end }}
#
#      {{ define "telegram_message" }}
#      {{ if gt (len .Alerts.Firing) 0 }}
#      *Alerts Firing:*
#      {{ range .Alerts.Firing }}• {{ .Labels.instance }}: {{ .Annotations.description }}
#      {{ end }}{{ end }}
#      {{ if gt (len .Alerts.Resolved) 0 }}
#      *Alerts Resolved:*
#      {{ range .Alerts.Resolved }}• {{ .Labels.instance }}: {{ .Annotations.description }}
#      {{ end }}{{ end }}{{ end }}
#
#      {{ define "telegram_text" }}{{ template "telegram_title" .}}
#      {{ template "telegram_message" . }}{{ end }}
# @param receivers
#  An array of receivers.
#  Example:
#  prometheus::sachet::receivers:
#  - name: 'Telegram'
#    provider: telegram
#    text: '{{ template "telegram_message" . }}'
# @param providers
#  An hash of providers.
#  See https://github.com/messagebird/sachet/blob/master/examples/config.yaml for more examples
#  Example:
#  prometheus::sachet::providers:
#    telegram:
#      token: "724679217:aa26V5mK3e2qkGsSlTT-iHreaa5FUyy3Z_0"
# @param restart_on_change
#  Should puppet restart the service on configuration change? (default true)
# @param service_enable
#  Whether to enable the service from puppet (default true)
# @param service_ensure
#  State ensured for the service (default 'running')
# @param service_name
#  Name of the node exporter service (default 'sachet')
# @param user
#  User which runs the service
# @param version
#  The binary release version
class prometheus::sachet (
  Stdlib::Absolutepath $config_dir,
  Stdlib::Absolutepath $config_file,
  String $download_extension,
  Prometheus::Uri $download_url_base,
  Array[String] $extra_groups,
  String[1] $group,
  String[1] $package_ensure,
  String[1] $package_name,
  String[1] $user,
  String[1] $version,
  Array $receivers,
  Hash $providers,
  Array $templates,
  Boolean $purge_config_dir               = true,
  Boolean $restart_on_change              = true,
  Boolean $service_enable                 = true,
  Stdlib::Ensure::Service $service_ensure = 'running',
  String[1] $service_name                 = 'sachet',
  Prometheus::Initstyle $init_style       = $prometheus::init_style,
  Prometheus::Install $install_method     = $prometheus::install_method,
  Boolean $manage_group                   = true,
  Boolean $manage_service                 = true,
  Boolean $manage_user                    = true,
  String[1] $os                           = downcase($facts['kernel']),
  String $extra_options                   = '',
  Optional[Prometheus::Uri] $download_url = undef,
  String[1] $config_mode                  = $prometheus::config_mode,
  String[1] $arch                         = $prometheus::real_arch,
  Stdlib::Absolutepath $bin_dir           = $prometheus::bin_dir,
  Stdlib::Port $listen_port               = 9876,
  Optional[String[1]] $bin_name           = undef,
) inherits prometheus {
  $real_download_url = pick($download_url,"${download_url_base}/download/${version}/${package_name}-${version}.${os}-${arch}.${download_extension}")

  $notify_service = $restart_on_change ? {
    true    => Service[$service_name],
    default => undef,
  }

  file { $config_dir:
    ensure  => 'directory',
    owner   => 'root',
    group   => $group,
    purge   => $purge_config_dir,
    recurse => $purge_config_dir,
  }

  $template_dir = "${config_dir}/templates"
  file { $template_dir:
    ensure  => 'directory',
    owner   => 'root',
    group   => $group,
    purge   => $purge_config_dir,
    recurse => $purge_config_dir,
    require => File[$config_dir],
  }

  $templates.each |Hash $template| {
    file { "${template_dir}/${template[name]}.tmpl":
      ensure  => file,
      owner   => 'root',
      group   => $group,
      mode    => $config_mode,
      content => $template[template],
      require => File[$template_dir],
    }
  }

  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => $group,
    mode    => $config_mode,
    content => template('prometheus/sachet.yaml.erb'),
    notify  => $notify_service,
    require => File[$config_dir],
  }

  $options = join([$extra_options, "-config ${config_file}", "-listen-address :${listen_port}"], ' ')

  prometheus::daemon { $service_name:
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    purge              => $purge_config_dir,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
    bin_name           => $bin_name,
  }
}
