#!/bin/bash
#
# Name:         duplicate-ora-coh-oim.bash
#
# Function:     This script duplicate Oracle database from Oracle backup 
#               in nfs mount.
#
#
# Show Usage: run the command to show the usage
#
# Changes:
# 06/16/2020 Diana Yang   New script (duplicate using target database)
# 07/06/2020 Diana Yang   Add duplicate option from backup location
#
#################################################################

function show_usage {
echo "usage: duplicate-ora-coh-oim.bash -r <RMAN login> -b <backup host> -a <target host> -s <Source Oracle database> -t <Target Oracle database> -f <file contain duplicate settting> -i <file contain setting to new spfile> -m <mount-prefix> -n <number of mounts> -p <number of channels> -o <ORACLE_HOME> -c <pluggable database>" 
echo " -r : RMAN login (example: \"rman auxiliary / \", optional)"
echo " -b : backup host" 
echo " -a : target host (Optional, default is localhost)"
echo " -s : Source Oracle database" 
echo " -t : Target Oracle database"
echo " -f : File contains duplicate settting, example: set newname for database to '/oradata/restore/orcl/%b'; "
echo " -i : File contains new setting to spfile. example: SET DB_CREATE_FILE_DEST +DGROUP3"
echo " -m : mount-prefix (like /coh/ora)"
echo " -n : number of mounts"
echo " -p : number of channels (Optional, default is same as the number of mounts4)"
echo " -o : ORACLE_HOME (Optional, default is current environment)"
echo " -c : pluggable database (if this input is empty, it is CDB database restore"
}

while getopts ":r:b:a:s:t:f:m:n:p:i:o:c:" opt; do
  case $opt in
    r ) rmanlogin=$OPTARG;;
    b ) shost=$OPTARG;;
    a ) thost=$OPTARG;;
    s ) sdbname=$OPTARG;;
    t ) tdbname=$OPTARG;;
    f ) ora_pfile=$OPTARG;;
    i ) ora_spfile=$OPTARG;;
    m ) mount=$OPTARG;;
    n ) num=$OPTARG;;
    p ) parallel=$OPTARG;;
    o ) oracle_home=$OPTARG;;
    c ) pdbname=$OPTARG;;
  esac
done

#echo $rmanlogin $sdbname, $mount, $shost, $num

# Check required parameters
#if test $shost && test $sdbname && test $tdbname && test $tdbdir && test $mount && test $num
if test $shost && test $sdbname && test $tdbname && test $mount && test $num
then
  :
else
  show_usage 
  exit 1
fi


function setup {
if test $thost
then
  :
else
  thost=`hostname -s`
fi

if test $parallel
then
  :
else
  echo "no input for parallel, set parallel to be $num."
  parallel=$num
fi

echo $rmanlogin
if [[ -z $rmanlogin ]]; then
  rmanlogin="rman auxiliary /"
  echo "rman login command is $rmanlogin"
else 
  if [[ $rmanlogin = *auxiliary* ]]; then
#  echo *auxiliary*
    echo "rman login command is $rmanlogin"
  else
    echo "rmanlogin syntax should be \"rman auxiliary / \""
    exit 1
  fi
fi

if test $oracle_home; then
#  echo *auxiliary*
  echo "ORACLE_HOME is $oracle_home"
  ORACLE_HOME=$oracle_home
  export ORACLE_HOME=$oracle_home
  export PATH=$PATH:$ORACLE_HOME/bin
else
  oracle_h=`env | grep ORACLE_HOME`
  if [[ -z $oracle_h ]]; then
     echo " is not defined. Need to specify ORACLE_HOME"
     exit 1
  fi   
fi
export NLS_DATE_FORMAT='DD:MM:YYYY-HH24:MI:SS'

DATE_SUFFIX=`/bin/date '+%Y%m%d%H%M%S'`
#echo $DATE_SUFFIX

DIRcurrent=$0
DIR=`echo $DIRcurrent |  awk 'BEGIN{FS=OFS="/"}{NF--; print}'`
if [[ $DIR = '.' ]]; then
  DIR=`pwd`
fi

if [[ ! -d $DIR/log/$thost ]]; then
  echo " $DIR/log/$thost does not exist, create it"
  mkdir -p $DIR/log/$thost
  
  if [ $? -ne 0 ]; then
    echo "create log directory $DIR/log/$thost failed. There is a permission issue"
    exit 1
  fi
fi

drmanlog=$DIR/log/$thost/$tdbname.rman-duplicate.$DATE_SUFFIX.log
drmanfiled=$DIR/log/$thost/$tdbname.rman-duplicate.$DATE_SUFFIX.rcv
drmanfiled_b=$DIR/log/$thost/$tdbname.rman-duplicate_b.$DATE_SUFFIX.rcv
drmanfiled_e=$DIR/log/$thost/$tdbname.rman-duplicate_e.$DATE_SUFFIX.rcv

if [[ ! -d "${mount}1/$shost/$sdbname/datafile" ]]; then
   echo "Directory ${mount}1/$shost/$sdbname/datafile does not exist, no backup files"
   exit 1
fi
	
#echo ${mount}1/$shost/$sdbname/datafile

# setup backup location
backup_location=/tmp/orarestore/$thost/$tdbname
echo backup_location is $backup_location
if [[ ! -d ${backup_location} ]]; then
   mkdir -p ${backup_location}/controlfile
   mkdir -p ${backup_location}/datafile
   mkdir -p ${backup_location}/archivelog
else
   /bin/rm -r ${backup_location}/*
   mkdir -p ${backup_location}/controlfile
   mkdir -p ${backup_location}/datafile
   mkdir -p ${backup_location}/archivelog
fi
# clean all files in ${backup_lcation} directory

# setup restore location
# get restore location from $ora_pfile
if [[ ! -z $ora_pfile ]]; then
   echo "ora_pfile is $ora_pfile"
   db_location=`grep -i newname $ora_pfile | awk -F "'" '{print $2}' | awk -F "%" '{print $1}'` 
# remove all space in $db_location
   db_location=`echo $db_location | xargs echo -n`
   echo new db_location is ${db_location}
# check whether it is ASM or dirctory
   if [[ ${db_location:0:1} != "#" ]]; then 
      echo "new db_location is a directory"
      if [[ ! -d ${db_location}data ]]; then
         echo "${db_location}/data does not exist, create it"
         mkdir -p ${db_location}data
      fi
      if [[ ! -d ${db_location}fra ]]; then
         echo "${db_location}/fra does not exist, create it"
         mkdir -p ${db_location}fra

         if [ $? -ne 0 ]; then
            echo "create new directory ${db_location} failed"
            exit 1
         fi
      fi
   fi 
else
   echo "there is no ora_pfile"
fi

# get restore locaton from $ora_spfile
if [[ ! -z $ora_spfile ]]; then
   echo "ora_spfile is $ora_spfile"
# check db_create_file_dest location
   db_create_location=`grep -i db_create_file_dest $ora_spfile | awk -F "'" '{print $2}' | awk -F "%" '{print $1}'`
   echo db_create_location is $db_create_location
# remove all space in $db_location
   db_create_location=`echo $db_create_location | xargs echo -n`
   echo db_create_location is $db_create_location
# check whether it is ASM or dirctory
   if [[ ${db_create_location:0:1} != "#" ]]; then
      echo "new db_create_location is a directory"
      if [[ ! -d ${db_create_location}/data ]]; then
         echo "${db_create_location}/data does not exist, create it"
         mkdir -p ${db_create_location}/data
      fi
      if [[ ! -d ${db_create_location}/fra ]]; then
         echo "${db_create_location}/fra does not exist, create it"
         mkdir -p ${db_create_location}/fra

         if [ $? -ne 0 ]; then
            echo "create new directory ${db_create_location}/fra failed"
            exit 1
         fi
      fi
   fi
else
   echo "there is no ora_spfile"
fi

#echo $thost  $mount $num

#trim log directory
find $DIR/log/$thost -type f -mtime +7 -exec /bin/rm {} \;

if [ $? -ne 0 ]; then
  echo "del old logs in $DIR/log/$thost failed"
  exit 2
fi

export ORACLE_SID=$tdbname
}

function create_softlink {

# get itime from $ora_pfile file
# covert the time to numeric 
if [[ ! -z $ora_pfile ]];then
   itime=`grep to_date $ora_pfile | awk -F "'" '{print $2}'`
   echo "itime is $itime"

   if [[ -z $itime ]]; then
      itime=`/bin/date '+%Y%m%d%H%M%S'`
      echo itime is $itime
      ptime=$itime
      echo "itime is $itime,  point-in-time restore time $ptime"  
   else   
      ptime=`/bin/date -d "$itime" '+%Y%m%d%H%M%S'`
      echo "itime is $itime,  point-in-time restore time $ptime"
   fi
else
   itime=`/bin/date '+%Y%m%d%H%M%S'`
   echo itime is $itime
   ptime=$itime
   echo "itime is $itime,  point-in-time restore time $ptime"  
fi

#create softlink of the right control file
cd ${mount}1/$shost/$sdbname/controlfile

echo "get point-in-time controlfile"
bfile=`ls -t | head -n 1`
bitime=`ls -l $bfile | awk '{print $6 " " $7 " " $8}'`
btime=`/bin/date -d "$bitime" '+%Y%m%d%H%M%S'`
#     echo file time $btime
#     echo ptime $ptime
if [[ $ptime -lt $btime ]]; then
   echo "This is no the recent backup. Need to refresh the mount with the right backup at $itime using prepare-restore.bash"
   exit   
else
   controlfile=$bfile
fi
echo "The controlfile is $controlfile"
ln -s ${mount}1/$shost/$sdbname/controlfile/$controlfile $backup_location/controlfile/$controlfile

#create softlink of the data files
cd ${mount}1/$shost/$sdbname/datafile

num_dfile=`ls *_data_*| wc -l`
dfile=(`ls *_data_*`)
i=1
j=0
while [ $i -le $num ]; do
  if mountpoint -q "${mount}${i}"; then
#    echo "$mount${i} is mount point"
	
#    if [[ ! -d "${mount}${i}/$shost/$sdbname/datafile" ]]; then
#       echo "Directory ${mount}${i}/$shost/$sdbname/datafile does not exist, no backup files"
#	   exit 1
#    fi
	
    if [[ $j -lt $num_dfile ]]; then
       ln -s ${mount}${i}/$shost/$sdbname/datafile/${dfile[$j]} $backup_location/datafile/${dfile[$j]}
    fi

    i=$[$i+1]
    j=$[$j+1]


    if [[ $i -gt $num && $j -le $num_dfile ]]; then 
       i=1
    fi
  else
    echo "$mount${i} is not a mount point. duplicate will not start"
    echo "The mount prefix may not be correct or"
    echo "The input of the number of mount points may exceed the actuall number of mount points"
    exit 1
  fi
done

#create softlink of the archivelogs
cd ${mount}1/$shost/$sdbname/archivelog

num_afile=`ls | wc -l`
afile=(`ls`)
#echo ${afile[0]}
i=1
j=0
while [ $i -le $num ]; do
  
  if [[ $j -lt $num_afile ]]; then
     ln -s ${mount}${i}/$shost/$sdbname/archivelog/${afile[$j]} $backup_location/archivelog/${afile[$j]}
  fi

  i=$[$i+1]
  j=$[$j+1]


  if [[ $i -gt $num && $j -le $num_afile ]]; then 
     i=1
  fi
  
done
}

function create_rman_duplicate_file {

echo "Create rman duplicate file"
echo "RUN {" >> $drmanfiled_b

i=1
j=1
while [ $i -le $num ]; do

  if [[ $j -le $parallel ]]; then
     echo "allocate auxiliary channel fs$j device type disk format = '$mount$i/$shost/$sdbname/datafile/%d_%T_%U';" >> $drmanfiled_b
     echo "release channel fs$j;" >> $drmanfiled_e
  fi

  i=$[$i+1]
  j=$[$j+1]


  if [[ $i -gt $num && $j -le $parallel ]]; then 
     i=1
  fi
done

#echo "ora_pfile is $ora_pfile"
#more $ora_pfile
if [[ ! -z $ora_pfile ]]; then
  if test -f $ora_pfile; then
    grep -v "^#" < $ora_pfile | { while IFS= read -r para; do
       para=`echo $para | xargs echo -n`
       echo $para >> $drmanfiled_b
    done }
  else
    echo "$ora_pfile does not exist"
    exit 1
  fi
fi

if [[ ! -z $ora_spfile ]]; then
  if test -f $ora_spfile; then
    if [[ -z $pdbname ]]; then
       echo "duplicate target database to $tdbname BACKUP LOCATION '$backup_location'" >> $drmanfiled_b
    else
       echo "duplicate target database to $tdbname pluggable database $pdbname BACKUP LOCATION '$backup_location'" >> $drmanfiled_b
    fi
    echo "SPFILE" >> $drmanfiled_b
    grep -v "^#" < $ora_spfile | { while IFS= read -r spara; do
       para=`echo $spara | xargs echo -n`
       echo $spara >> $drmanfiled_b
    done }
    echo "nofilenamecheck;" >> $drmanfiled_b
  else
     echo "$ora_spfile does not exist"
     exit 1
  fi
else
  if [[ -z $pdbname ]]; then
     echo "duplicate target database to $tdbname BACKUP LOCATION '$backup_location' nofilenamecheck;" >> $drmanfiled_b
  else
     echo "duplicate target database to $tdbname pluggable database $pdbname BACKUP LOCATION '$backup_location' nofilenamecheck;" >> $drmanfiled_b
  fi
fi  

cat $drmanfiled_b $drmanfiled_e > $drmanfiled

echo "}" >> $drmanfiled
echo "exit;" >> $drmanfiled

echo "finished creating rman duplicate file"
}


function duplicate {

echo "Database duplicate started at " `/bin/date '+%Y%m%d%H%M%S'`
echo "ORACLE SID is $ORACLE_SID"

$rmanlogin log $drmanlog @$drmanfiled

echo "If Oracle duplicate job fails, Check whether Oracle database $tdbname started in nomount mode"
ls -l ${ORACLE_HOME}/dbs/spfile*
echo "If Oracle duplicate job fails and it is PDB restore, Check whether Oracle database $tdbname is started"
echo "Database duplicate finished at " `/bin/date '+%Y%m%d%H%M%S'`

echo "The last 10 line of rman log output"
echo " "
tail $drmanlog 
}

setup
create_softlink
create_rman_duplicate_file
duplicate