#!/bin/bash
#
# Brandon Gant
# 2014-02-07
#
# This script is run by the Guest account.
#

SERVER="<Your_rsync_Server>"
TRAINVM="<Your_Windows_Server>"

while [ `rsync $SERVER:: | grep -c training-desktops` -lt "1" ] 
do
   echo "waiting for network connection..."
   sleep 1
done 

# If /tmp/reboot exists, don't bother connecting to TrainVM yet...
if [ -e /tmp/reboot ]
then
   exit 0
fi

while true
do
   sleep 3

   # Connect to Training Server VM
   #rdesktop -u "" -f -P -a 24 -5 $TRAINVM
   xfreerdp --ignore-certificate --sec tls -f $TRAINVM
done

