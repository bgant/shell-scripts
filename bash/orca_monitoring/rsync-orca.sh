#!/bin/bash
#
# /root/scripts/orca_rsync.sh
#

# Check to see if procallator is running (if not start it)
value=`ps -e -o args | grep "procallator.pl" | grep -v grep`
if [[ -z $value ]]; then
     /etc/init.d/procallator start
fi
sleep 5

# Copy procallator data to Orca server
SERVER=`uname -n | cut -d"." -f1`       # Server Name Only
RSYNC="/usr/bin/rsync --archive --itemize-changes" 

$RSYNC /usr/local/procallator/ <Your_Orca_Server>::orca/$SERVER/
