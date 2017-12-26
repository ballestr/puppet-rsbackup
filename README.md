# puppet-rsbackup
puppet module for rsbackup
* https://github.com/ballestr/rsbackup

## Usage

Example with both local and one remote backup:
```
    ## RsBackup
    include rsbackup::local
    rsbackup::remote{"SG":pre=>false}
```
