class rsbackup::params {
    $rsbakdir='/opt/rsbak'
    $cfgsrc=hiera('rsbackup/cfgsrc','puppet:///files_site/rsbackup') #lint:ignore:puppet_url_without_modules
}
