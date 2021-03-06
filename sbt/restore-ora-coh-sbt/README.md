## Download the script
- curl -O https://raw.githubusercontent.com/diana-hui-yang/rman-cohesity/master/sbt/restore-ora-coh-sbt/restore-ora-coh-sbt.bash
- chmod 750 restore-ora-coh-sbt.bash

## Description
The scripts restores database uses Cohesity Source-side dedup library, and from the backup files created by script backup-ora-coh-sbt.bash

When run the script without any options, it displays the script usage

Required parameters

- -i : Oracle instance name. If it is not RAC, it is the same as DB name. If it is RAC, it is the instance name like cohcdba2
- -j : file that has vip list
- -v : Cohesity view
- -s : Cohesity SBT library name including directoy or just directory (default name is libsbt_6_and_7_linux-x86_64.so)
- -f : yes means force. It will restore Oracle database. Without it, it will just run RMAN validate (Optional)

Optional Parameters

- -r : RMAN login (example: \"rman target / \"), optional
- -h : backup host (default is current host), optional
- -d : Oracle database name. only required for RAC. If it is RAC, it is the database name like cohcdba
- -c : File contains restore location setting, example: set newname for database to '/oradata/restore/orcl/%b';
- -t : Point in Time (format example: "2019-01-27 13:00:00"), optional
- -l : yes means complete restore including control file, no means not restoring controlfile
- -p : number of channels (default is 4), optional
- -o : ORACLE_HOME (default is current environment), optional
- -w : yes means preview rman backup scripts 

## VIP file content example
- 10.19.2.6
- 10.19.2.7
- 10.19.2.8
- 10.19.2.9

## Restore exmaple

### Restore database validate example
- ./restore-ora-coh-sbt.bash -i orcl -j vip-list -v orasbt1 -s /u01/app/coheisty
### Restore database assuming controlfile are still intact
- ./restore-ora-coh-sbt.bash -i orcl -j vip-list -v orasbt1 -s /u01/app/coheisty -f yes
### Restore controlfile, then database
Note: before running this commaand, several prepare steps should be done first.
init file should be created, adump directory should be created. 
Check the scripts example in restore-example directory for for details
- ./restore-ora-coh-sbt.bash  -i orcl -t "2020-08-02 12:00:00" -l yes -j vip-list -v orasbt1 -s /u01/app/coheisty -f yes

## Restore exmaple from directory "orawest/orcl" under view "orasbt1" exmaple
The following example uses the directory "orawest/orcl" (host is orawest, the database is orcl) under view "orasbt1". You can mount the view to a Unix server to verify the backup files are in this directory.

### duplidate none CDB database example
### Restore database validate example
- ./restore-ora-coh-sbt.bash -i orcl -j vip-list -v orasbt1/orawest/orcl -s /u01/app/coheisty
### Restore database assuming controlfile are still intact
- ./restore-ora-coh-sbt.bash -i orcl -j vip-list -v orasbt1/orawest/orcl -s /u01/app/coheisty -f yes
### Restore controlfile, then database
Note: before running this commaand, several prepare steps should be done first.
init file should be created, adump directory should be created. 
Check the scripts example in restore-example directory for for details
- ./restore-ora-coh-sbt.bash  -i orcl -t "2020-08-02 12:00:00" -l yes -j vip-list -v orasbt1/orawest/orcl -s /u01/app/coheisty -f yes
