class rsbackup::client {
    include rsbackup::base

    ## setup for remote, restricted rsync
    $path="/opt/rsbak/bin"
    $script="$path/validate_rsync"
    ssh_authorized_key {
        "rsbackup":
            ensure=>present,user=>"root",type=>"ssh-rsa",
            options=>"command=\"$script\"",
            key=>hiera("rsbackup/sshkey");
    }

## we use the git checkout for the files
/*
    file { 
        "$path":
            ensure=>directory, mode=>700, owner=>root, group=>root;
        "$script":
            ensure=>present, mode=>700, owner=>root, group=>root,
            source=>"puppet:///modules/rsbackup/validate_rsync";
    }
*/
}

class rsbackup::local ($pre=false) {
    include rsbackup::serverbase

    rsbackup::cfgfile{"rsnapshot.local.conf":}
    if ($pre) {
        rsbackup::cfgfile{["rsnapshot.local.pre"]:}
    }
    ## note that Debian does not like any extension in a crontab filename, so no to .cron
    rsbackup::cfgfile{"rsbackup_local_cron":path=>"/etc/cron.d"}
}

define rsbackup::remote($pre=false) {
    include rsbackup::remote::base
    rsbackup::cfgfile{["rsnapshot.remote_${name}.conf"]:}
    if ($pre) {
        rsbackup::cfgfile{["rsnapshot.remote_${name}.pre"]:}
    }
}

class rsbackup::remote::base {
    include rsbackup::server::base
    $key="/root/.ssh/id_rsa_rsbackup"
    exec {"rsbackup_create_key":
    command=>"/bin/ssh-keygen -t rsa -N '' -C \"rsbackup@$(hostname -s)_$(date +%Y%m%d)\" -f $key",
    creates=>"$key"
    }
    ## rsbackup::cfgfile{["rsnapshot.exclude"]:} ## what if we do not want local backup?
    rsbackup::cfgfile{"ssh.config":}
    rsbackup::cfgfile{"rsbackup_remote_cron":path=>"/etc/cron.d"}
}


define rsbackup::cfgfile ($path="/etc/rsbackup"){
    $FILES=hiera("rsbackup/files","puppet:///files_site/rsbackup")
    file {"$path/$name":
        source=>[
        "$FILES/${name}^${hostname}",
        "$FILES/${name}",
        "puppet:///modules/rsbackup/${name}"
        ],
        notify=>Exec["rsbackup_configtest"]
    }
}

class rsbackup::server::base {
    include rsbackup::base
    package {"rsnapshot":ensure=>present}
    rsbackup::cfgfile{"rsnapshot.exclude":}
}

## base for both client and server
class rsbackup::base {
    package {"rsync":ensure=>present}

    $rsbakdir="/opt/rsbak"
    $group=hiera("rsbackup/group","nagios") ## allow servicecheck to execute rsbackstatus.sh as nagios
    $gitrepo=hiera("rsbackup/gitrepo","https://github.com/ballestr/rsbackup.git")
    vcscheck::git {"rsbackup":path=>"$rsbakdir",source=>$gitrepo,create=>true}

    ## assume we are on standard linux, not Synology DSM + oPKG
    file {"/opt/bin": ensure=>directory,
        owner=>root,group=>root,mode=>0755 }
    file {"/opt/bin/bash": target=>"/bin/bash"}

    file {"/var/log/rsbackup": ensure=>directory,
        owner=>root,group=>$group,mode=>0750 }

    ## Configuration directory and files
    file {"/opt/rsbak/etc": target=>"/etc/rsbackup"}
    file {"/etc/rsbackup": ensure=>directory,
        owner=>root,group=>$group,mode=>0750 }
    rsbackup::cfgfile{"rsbackup.rc":}
    exec {"rsbackup_configtest":
        command=>"/opt/rsbak/configtest.sh",
        refreshonly => true,
        subscribe=>File["/etc/rsbackup/rsbackup.rc"]
    }
    file {"/etc/cron.d/rsbackup_status_cron":
        content=>"## Managed by Puppet rsbackup::base ##\n30  7    *   *   *  root      /opt/rsbak/bin/rsbackstatus.sh -m\n"
    }
}
