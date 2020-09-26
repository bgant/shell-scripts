#!/bin/bash 

#--- setup environment for procallator data collector
#--- tested on UBUNTU and CENTOS linux 


  install --preserve-timestamps --owner=root --group=root --mode=0744 --target-directory=/etc/init.d ./procallator
  ln -s /etc/init.d/procallator /etc/rc3.d/S99procallator
  ln -s /etc/init.d/procallator /etc/rc3.d/K99procallator
  install --preserve-timestamps --owner=root --group=root --mode=0744 --target-directory=/usr/local/bin ./procallator.pl
  install --preserve-timestamps --owner=root --group=root --mode=0744 --target-directory=/root/scripts ./rsync-orca.sh

# append to /etc/crontab:
 cat <<EOD >> /etc/crontab

#-------- copy orca logs to central server and prune data files
0,5,10,15,20,25,30,35,40,45,50,55 * * * * root /root/scripts/rsync-orca.sh > /dev/null 2>&1
03 07 * * * root find /usr/local/procallator -name "proccol*" -mtime +15 -exec rm -f {} \; > /dev/null 2>&1

EOD
