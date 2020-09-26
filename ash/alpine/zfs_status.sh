#!/bin/ash
#
# Monitors ZFS Pool status on Alpine Linux
#
# ln -s zfs_status.sh /etc/periodic/15min/zfs_status   <-- NO .sh or it will not work
# run-parts /etc/periodic/15min                        <-- Test that cron is running script properly

ZFS=$(zpool status | grep state | grep -c ONLINE)

if [ $ZFS -eq "1" ]
then
   echo "ZFS RAIDZ1 pool is ONLINE and working fine..."
else
   echo
   echo "WARNING: ZFS RAIDZ1 is in a degraded state..."
   echo
   zpool status
   beep -l 1000 -d 2000 -f 830 -r 10
fi
