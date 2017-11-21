class rsbackup::client {
}

class rsbackup::local {
    include rsbackup::base
    package {"rsnapshot":ensure=>present}
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
	notify=>Exec["rsbackup_configtest"]
    }
    file {"/etc/rsbackup/rsnapshot.local.conf":
	source=>[
	"puppet:///files_site/rsbackup/rsnapshot.local.conf^${hostname}",
	"puppet:///files_site/rsbackup/rsnapshot.local.conf",
	"puppet:///modules/rsbackup/rsnapshot.local.conf"
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
    refreshonly => true
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
