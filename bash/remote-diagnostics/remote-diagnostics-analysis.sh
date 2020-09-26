#!/bin/bash
#
# Give this script a log file name and it will check for changes and archive when something happens

LOGFILE=$1
ARCHIVE="$LOGFILE-history"

if [ -n "$LOGFILE" ]
then

for LOGDIR in `find /opt/remote-diagnostics/clients/ -name $LOGFILE.log -print | sed "s/\/$LOGFILE.log//g"`
do 
  echo "$LOGDIR"
  if [ -n "`rsync --checksum --itemize-changes --dry-run $LOGDIR/$LOGFILE.log $LOGDIR/.$LOGFILE.log`" ]
  then
       if [ ! -e "$LOGDIR/$ARCHIVE" ]
       then
           echo "Creating $LOGDIR/$ARCHIVE directory"
           mkdir $LOGDIR/$ARCHIVE
       fi
       cp $LOGDIR/$LOGFILE.log $LOGDIR/$ARCHIVE/$LOGFILE.`date +%Y-%m-%d-%H%M`.log
       cp $LOGDIR/$LOGFILE.log $LOGDIR/.$LOGFILE.log
  fi

# Delete log files older than 7 days?
#find /opt/remote-diagnostics/clients/ -mtime +7 -print | grep "\.log" | grep "\-history\/" | xargs rm
  
done

else
echo "Specify logfile name as a argument to this script."
fi


exit 0
