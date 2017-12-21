## setup a client/target system
class rsbackup::client inherits rsbackup::params {
    include rsbackup::base

    ## setup for remote, restricted rsync
    $path="${rsbakdir}/bin"
    $script="${path}/validate_rsync"
    ssh_authorized_key {
        'rsbackup':
            ensure  =>present,
            user    =>'root',
            type    =>'ssh-rsa',
            options =>"command=\"${script}\"",
            key     =>hiera('rsbackup/sshkey');
    }
    ## we still use the git checkout for the files
}

## setup a server for local backups only, no remote (SSH) clients
class rsbackup::local ($pre=false) {
    include rsbackup::server::base

    rsbackup::cfgfile{'rsnapshot.local.conf':}
    if ($pre) {
        rsbackup::cfgfile{['rsnapshot.local.pre']:}
    }
    ## note that Debian does not like any extension in a crontab filename, so no to .cron
    rsbackup::cfgfile{'rsbackup_local_cron':path=>'/etc/cron.d'}
}

## Setup a server for remote (SSH) backups
## specific configuration file
define rsbackup::remote($pre=false) {
    include rsbackup::remote::base
    rsbackup::cfgfile{["rsnapshot.remote_${name}.conf"]:}
    if ($pre) {
        rsbackup::cfgfile{["rsnapshot.remote_${name}.pre"]:}
    }
}

## Setup a server for remote (SSH) backups
## base configuration
class rsbackup::remote::base {
    include rsbackup::server::base
    $keyfile='/root/.ssh/id_rsa_rsbackup'
    exec {'rsbackup_create_key':
        command =>"/bin/ssh-keygen -t rsa -N '' -C \"rsbackup@$(hostname -s)_$(date +%Y%m%d)\" -f ${keyfile}",
        creates =>$keyfile
    }
    ## rsbackup::cfgfile{["rsnapshot.exclude"]:} ## what if we do not want local backup?
    rsbackup::cfgfile{'ssh.config':}
    rsbackup::cfgfile{'rsbackup_remote_cron':path=>'/etc/cron.d'}
}

## generic configuration file for rsbackup
define rsbackup::cfgfile ($path='/etc/rsbackup') {
    include rsbackup::params
    file {"${path}/${name}":
        source =>[
        "${rsbackup::params::cfgpath}/${name}^${::hostname}",
        "${rsbackup::params::cfgpath}/${name}",
        "puppet:///modules/rsbackup/${name}"
        ],
        notify =>Exec['rsbackup_configtest']
    }
}

## base configuration for server
class rsbackup::server::base {
    include rsbackup::base
    package {'rsnapshot':ensure=>present}
    rsbackup::cfgfile{'rsnapshot.exclude':}
}

## base configuration for both client and server
class rsbackup::base inherits rsbackup::params {
    package {'rsync':ensure=>present}

    $group=hiera('rsbackup/group','root') ## allow servicecheck to execute rsbackstatus.sh e.g. as nagios
    $gitrepo=hiera('rsbackup/gitrepo','https://github.com/ballestr/rsbackup.git')
    $deployfile="${rsbakdir}/_deployed_by_puppet.txt"
    if ( $gitrepo =~ /^puppet:/ ) {
        file {$rsbakdir: source =>$gitrepo,recurse=>true,ignore=>['etc','.git']}
        file {$deployfile: content =>"source=${gitrepo} on ${servername}\n"}
    } else {
        vcscheck::git {'rsbackup': path=>$rsbakdir,source=>$gitrepo,create=>true}
        file {$deployfile: ensure=>absent}
    }

    ## assume we are on standard linux, not Synology DSM + oPKG
    ## so we need to provide /opt/bin/bash
    file {'/opt/bin': ensure=>directory,owner=>root,group=>root,mode=>'0755' }
    file {'/opt/bin/bash': target=>'/bin/bash'}

    file {'/var/log/rsbackup': ensure=>directory,owner=>root,group=>$group,mode=>'0750' }

    ## Configuration directory and files
    file {"${rsbakdir}/etc": target=>'/etc/rsbackup'}
    file {'/etc/rsbackup': ensure=>directory,owner=>root,group=>$group,mode=>'0750' }
    rsbackup::cfgfile{'rsbackup.rc':}
    exec {'rsbackup_configtest':
        command     =>"${rsbakdir}/configtest.sh",
        refreshonly => true,
        subscribe   =>File['/etc/rsbackup/rsbackup.rc'],
        require     =>File['/opt/bin/bash']
    }
    file {'/etc/cron.d/rsbackup_status_cron':
        content =>"## Managed by Puppet rsbackup::base ##\n30  7    *   *   *  root      ${rsbakdir}/bin/rsbackstatus.sh -m\n"
    }
}
