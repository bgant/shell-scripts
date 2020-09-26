#!/bin/bash
#
# Brandon Gant
# 2015-06-18
#
# This script checks to see if renice-oracle.sh is running.
#
# Q. Why not just run renice-oracle.sh from the /etc/crontab?
# A. The crond daemon itself has a nice value of zero (just like
# the oracle processes). So cron would not be able to interrupt the
# oracle processes to run any commands.
#

PID=`ps -e -o pid -o comm | grep renice-oracle | awk -F' ' '{print $1}'`
LOCKFILE="/var/run/renice-oracle.pid"

if [ -n "$PID" ]
then
   echo "renice-oracle.sh script is running: $PID"
else
   echo "renice-oracle.sh script is not running... Starting now..."
   if [ -e $LOCKFILE ]
   then
      rm -v $LOCKFILE
   fi
   nice -n -1 /root/scripts/renice-oracle.sh &
fi

exit 0
