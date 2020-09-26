#!/bin/bash

###################################################
# Create: ssh <Prod Oracle Server>
#         cd /u01/app/oracle
#         sudo find data/ -type f -print | grep .dbf > /tmp/rsync-oracle-data.list
#         sudo find idx/ -type f -print | grep .dbf >> /tmp/rsync-oracle-data.list
#         scp rsync-oracle-data.list <newserver>:/root/scripts/
###################################################

SERVER="127.0.0.1"
DATAFILE="/opt/pure-to-compellent/rsync-oracle-data.list"
TOTALFILES=`wc -l $DATAFILE | awk -F' ' '{print $1}'`
RSYNC="rsync --archive --inplace --whole-file --partial"
SOURCEDIR="u01/app/oracle"
TARGETDIR="compellent/app/oracle"
# --archive is an exact recursive copy with permissions and timestamps preserved
# --inplace writes over the file instead of creating a hidden temp file and moving the file when transferred
# --partial does not remove partially written data if the rsync process stops or is killed
# --whole-file just copies the entire file again if the checksum/timestamp is different 
# --no-whole-file does a delta of the file to only copies the blocks that have changed
# Copying the entire 4GB file again is faster than using CPU to scan the file for changes and then copying the changes


# Disk throughput and ops per second seems to be higher with lower THROTTLE numbers
# (viewed with vcenter performance and storage controller graphs)
THROTTLE="6"

###################################################

# The "$$" variable contains the PID of this script when it is running.

WAITING () 
{
  #ps -e -o etime -o ppid -o args | grep $$ | grep -v grep | grep rsync | sort -k 3
  #ps -e -o pid -o ppid -o comm | grep rsync | grep $$ | awk -F' ' '{print $1}' | xargs -I {} sudo pargs -l {} | awk -F' ' '{print $7}' | sort

PSLIST=`ps -e -o etime -o ppid -o pid -o comm | grep $$ | grep rsync$`
IFS="
"
  for PSLINE in $PSLIST
  do
     PSETIME=`echo "$PSLINE" | awk -F' ' '{print $1}'`
     PSPID=`echo "$PSLINE" | awk -F' ' '{print $3}'`
     #PSARGS=`pargs -l $PSPID | awk -F' ' '{print $7}'`
     #PSARGS=`ps -e -p $PSPID | grep "rsync$" | awk -F'/' '{print $11}' | awk -F' ' '{print $1}'`
     PSARGS=`ps -e -o pid -o args | grep $PSPID | awk -F'/' '{print $12}'`
     FILENUMBER=`grep -n "$PSARGS" "$DATAFILE" | awk -F':' '{print $1}'`
     FILESIZE=`du -h /$TARGETDIR/*/*/$PSARGS | awk -F' ' '{print$1}'`
     if [ ! -z $PSARGS ]
     then
        sleep 0.1
        echo -e "      $PSETIME  $PSARGS \t($FILENUMBER/$TOTALFILES) \t$FILESIZE"
     fi
  done
unset IFS

  sleep 5
  echo
}

#if [ `df -P | grep -c /opt/oracle/data` -le 0 ]
#then
#  echo "Oracle volumes do not appear to be mounted"
#  exit 1
#fi

echo
echo "##########################################"
echo "Start: `date`"
START=`date`

LIB=`echo $1 | tr '[:lower:]' '[:upper:]'`

DATA=`cat $DATAFILE`

if [ -z "$LIB" ]
then
   echo "You need to choose a library: <XXX|ALL>"
   exit
elif [[ "$LIB" =~ "ALL" ]]
then
   echo "You have chosen to sync all databases..."
else
   DATA=`echo "$DATA" | grep -i $LIB`
   #echo "$DATA"
   echo
fi

if [ -z "$DATA" ]
then
   echo "DATA is empty"
   exit
fi

# Build directory structure only
nice rsync -aq -f"+ */" -f"- *" $SERVER::$SOURCEDIR/data/ /$TARGETDIR/data/
nice rsync -aq -f"+ */" -f"- *" $SERVER::$SOURCEDIR/idx/ /$TARGETDIR/idx/

for LINE in $DATA
do
   # Rsync individual 4GB Oracle files
   nice $RSYNC $SERVER::$SOURCEDIR/$LINE /$TARGETDIR/$LINE &
   sleep 0.1

   while [ `pgrep -P $$ -x rsync | wc -l` -ge "$THROTTLE" ]
   do
      echo "Max $THROTTLE rsync jobs are running..."
      WAITING
   done

done

sleep 0.5

# Waiting for the last few that are below the THROTTLE to finish...
while [ `pgrep -P $$ -x rsync | wc -l` -gt 0 ]
do
   echo "Waiting for the final processes to finish..."
   WAITING
done

echo 
#echo "Data Cleanup..."
#rm --recursive --force /u01/app/oracle/data/UCDB:
#rm --recursive --force /u01/app/oracle/idx/UCDB:
#chmod o+w /u01/app/oracle/*/UCDB/*.dbf
#chown oracle:oinstall /u01/app/oracle/data/*/*.dbf
#chown oracle:oinstall /u01/app/oracle/idx/*/*.dbf
#chmod ug+rw /u01/app/oracle/*/UIU/*.dbf

echo
echo "rsync jobs completed!"
echo "Start:  $START"
echo "Finish: `date`"
echo "##########################################"

