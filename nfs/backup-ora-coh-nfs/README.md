
## Download the script

- curl -O https://raw.githubusercontent.com/diana-hui-yang/rman-cohesity/master/nfs/backup-ora-coh-nfs/backup-ora-coh-nfs.bash
- curl -O https://raw.githubusercontent.com/diana-hui-yang/rman-cohesity/master/nfs/backup-ora-coh-nfs/sbackup-ora-coh-nfs.bash
- chmod 750 backup-ora-coh-nfs.bash
- chmod 750 sbackup-ora-coh-nfs.bash

## Backup scripts Description

Both backup-ora-coh-nfs.bash and sbackup-ora-coh-nfs.bash can utilize mutiple mount points to backup Oracle databases. The backup files are in Oracle backupset format.
It supports full, incremental, and archive logs backup options. It also supports recvoery catalog. backup-ora-coh-nfs.bash supports Linux and sbackup-ora-coh-nfs.bash supports Solaris.

When run the script without any options, it displays the script usage

 Required Parameters
- -h : host (scanname is required if it is RAC. optional if it is standalone.)
- -o : ORACLE_DB_NAME (Need to have an entry of this database in /etc/oratab. If it is RAC, it is db_unique_name)
- -a : yes (yes means archivelog backup only, no means database backup plus archivelog backup, no is optional)
- -i : If not archive only, it is full or incremental backup. 0 is full backup, and 1 is cumulative incremental backup
- -m : mount-prefix (like /mnt/ora)
- -n : number of mounts
- -e : Retention time (days to retain the backups, apply only after uncomment "Delete obsolete" in this script)

 Optional Parameters
- -r : RMAN login (example: "rman target /", optional)
- -p : number of channels (Optional, default is 4)
- -l : Archive logs retain days (days to retain the local archivelogs before deleting them. default is 1 day)
- -b : ORACLE_HOME (default is /etc/oratab, optional.)
- -w : yes means preview rman backup scripts

## backup-ora-coh-nfs.bash Backup Example
### Full backup example
./backup-ora-coh-nfs.bash -o orcl -a no -i 0 -m /coh/ora -n 4 -p 6 -e 30
### Cumulative backup example
./backup-ora-coh-nfs.bash -o orcl -a no -i 1 -m /coh/ora -n 4 -p 3 -e 30
### Archive log backup example
./backup-ora-coh-nfs.bash -o orcl -a yes -m /coh/ora -n 4 -p 2 -e 30

## Backup-ora-coh-nfs.bash RAC database backup Example
### Full backup example for RAC database
./backup-ora-coh-nfs.bash -h orascan -o orarac -a no -i 0 -m /coh/ora -n 4 -p 6 -e 30
### Cumulative backup example for RAC database
./backup-ora-coh-nfs.bash  -h orascan -o orarac -a no -i 1 -m /coh/ora -n 4 -p 3 -e 30
### Archive log backup example for RAC database
./backup-ora-coh-nfs.bash  -h orascan -o orarac -a yes -m /coh/ora -n 4 -p 2 -e 30

Note
RMAN "delete obsolete" command is used in this script to delete expired backups. Be default, it is commmented out. Please check Oracle Bug report and apply the necessary fixes before you uncomment that line.

"Oracle Bug 29633753 delete obsolete removes backup created inside recovery window of read only datafiles in nocatalog mode"

