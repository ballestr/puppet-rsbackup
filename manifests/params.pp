class rsbackup::params {
    $rsbakdir='/opt/rsbak'
    $cfgpath=hiera('rsbackup/files','puppet:///files_site/rsbackup') #lint:ignore:puppet_url_without_modules
}
