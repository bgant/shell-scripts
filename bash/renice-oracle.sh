#!/bin/bash
#
# Brandon Gant
# 2015-06-18
# 
# This script watches for user initiated "report" generation processes
# and reduces their priority over the system to run more in the background.
#
# This script needs a lower priority than the processes it is monitoring.
#    sudo nice -n -1 renice-oracle.sh &
#

# Check to see if it is already running...
LOCKFILE="/var/run/renice-oracle.pid"
if [ -e $LOCKFILE ]
then
   echo "Script is already running (see $LOCKFILE)... Exiting"
   exit 0
else
   # Create Lock File
   echo $$ > $LOCKFILE
fi

# Go into loop watching for suspect processes...
while true
do

PIDLIST=`ps -e -o pid -o cputime -o nice -o args | grep "LOCAL=" | grep -v "00:00:[0-2]" | grep -v "5 oracle" | awk -F' ' '{print $1}'`

for PID in $PIDLIST
do
  renice +5 -p "$PID"
  echo `date` `ps -e -o pid -o nice -o cputime -o etime -o args | grep -v grep | grep -w $PID` >> /var/log/renice-oracle.log
done

sleep 30
done

