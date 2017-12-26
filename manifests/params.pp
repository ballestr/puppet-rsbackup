class rsbackup::params {
    $rsbakdir='/opt/rsbak'
    $cfgsrc     = hiera('rsbackup/cfgsrc','puppet:///files_site/rsbackup') #lint:ignore:puppet_url_without_modules
    $cfgdst     = '/etc/rsbackup'
    # valid values: always, onerror, servicecheck. Default 'onerror' as the most usually desireable way.
    $statusmail = hiera('rsbackup/statusmail','onerror') 
}
