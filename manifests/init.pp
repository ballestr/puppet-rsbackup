class rsbackup::client {
    include rsbackup::base

    ## setup for remote, restricted rsync
    $path="/opt/rsbak/bin"
    $script="$path/validate_rsync"
    ssh_authorized_key {
        "rsbak":
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

class rsbackup::local () {
    include rsbackup::base
    package {"rsnapshot":ensure=>present}

    file {"/etc/rsbackup/rsnapshot.local.conf":
	source=>[
	"puppet:///files_site/rsbackup/rsnapshot.local.conf^${hostname}",
	"puppet:///files_site/rsbackup/rsnapshot.local.conf",
	"puppet:///modules/rsbackup/rsnapshot.local.conf"
	],
	notify=>Exec["rsbackup_configtest"]
    }
    file {"/etc/rsbackup/rsnapshot.local.pre":
	source=>[
	"puppet:///files_site/rsbackup/rsnapshot.local.pre^${hostname}",
	"puppet:///files_site/rsbackup/rsnapshot.local.pre",
	"puppet:///modules/rsbackup/rsnapshot.local.pre"
	],
	notify=>Exec["rsbackup_configtest"]
    }
    file {"/etc/rsbackup/rsnapshot.exclude":
	source=>[
	"puppet:///files_site/rsbackup/rsnapshot.exclude^${hostname}",
	"puppet:///files_site/rsbackup/rsnapshot.exclude",
	"puppet:///modules/rsbackup/rsnapshot.exclude"
	],
	notify=>Exec["rsbackup_configtest"]
    }
    exec {"rsbackup_configtest":
    command=>"/opt/rsbak/configtest.sh",
    refreshonly => true,
    subscribe=>File["/etc/rsbackup/rsbackup.rc"]
    }
    ## note that Debian does not like any extension in a crontab filename, so no to .cron
    file {"/etc/cron.d/rsbackup_cron":
	source=>[
	"puppet:///files_site/rsbackup/rsbackup.cron^${hostname}",
	"puppet:///files_site/rsbackup/rsbackup.cron",
	"puppet:///modules/rsbackup/rsbackup.cron"
	],
	notify=>Exec["rsbackup_configtest"]
    }

}
class rsbackup::remote {
    include rsbackup::local
    $key="/root/.ssh/id_rsa_rsbackup"
    exec {"rsbackup_create_key":
    command=>"/bin/ssh-keygen -t rsa -N '' -C \"rsbackup@$(hostname -s)_$(date +%Y%m%d)\" -f $key",
    creates=>"$key"
    }
}

class rsbackup::base {
    package {"rsync":ensure=>present}

    $rsbakdir="/opt/rsbak"
    $gitrepo="https://github.com/ballestr/rsbackup.git"
    vcscheck::git {"rsbackup":path=>"$rsbakdir",source=>$gitrepo}

    ## assume we are on standard linux, not Synology DSM + oPKG
    file {"/opt/bin": ensure=>directory,
	owner=>root,group=>root,mode=>0700 }
    file {"/opt/bin/bash": target=>"/bin/bash"}

    file {"/var/log/rsbackup": ensure=>directory,
	owner=>root,group=>root,mode=>0700 }

    ## Configuration directory and files
    file {"/opt/rsbak/etc": target=>"/etc/rsbackup"}
    file {"/etc/rsbackup": ensure=>directory,
	owner=>root,group=>root,mode=>0700 }
    file {"/etc/rsbackup/rsbackup.rc":
	source=>[
	"puppet:///files_site/rsbackup/rsbackup.rc^${hostname}",
	"puppet:///files_site/rsbackup/rsbackup.rc",
	"puppet:///modules/rsbackup/rsbackup.rc"
	],
	## notify=>Exec["rsbackup_configtest"] # subscribe from it instead
    }

    file {"/etc/cron.d/rsbackup_status_cron":
	content=>"## Managed by Puppet ##\n30  7    *   *   *  root	/opt/rsbak/bin/rsbackstatus.sh -m"
    }

}

