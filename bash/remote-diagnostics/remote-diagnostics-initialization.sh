#!/bin/bash
#
# Add or change comments to force reboots on all remote diagnostics machines! 
#    Random Text that will force reboot...

SERVER="remote-diagnostics.<Your_Domain>"

#==========================================#
#   Configure Ubuntu Mini Remix OS         #
#==========================================#

   # Enable Firewall
   ufw default deny
   ufw enable
  
   # Set Time and Timezone
   mv /etc/localtime /etc/localtime-UTC
   ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime 
   ntpdate ntp.illinois.edu

   # Install Extra Packages
   perl -p -i -e "s/# //g" /etc/apt/sources.list
   apt-get update
   apt-get -y install traceroute nmap ethtool

   # Set Hostname to MAC Address
   ifconfig | grep -m1 HWaddr | awk -F' ' '{print $5}' | perl -p -i -e "s/://g" | xargs -I {} hostname -b {}
   HOSTNAME=`uname -n`

   # Get ini file for this MAC Address (if it has been created)
   rsync --archive $SERVER::scripts/$HOSTNAME.ini /tmp/

   # Don't Eject CD or wait for user input on Restart or Shutdown
   perl -p -i -e "s/eject -p /#eject -p /g" /etc/init.d/casper
   perl -p -i -e "s/read x /#read x /g" /etc/init.d/casper

   # Copy created remote-diagnostics file to /tmp so that I can check it from server
   cp /etc/init.d/remote-diagnostics /tmp/remote-diagnostics.init

   # Setup cron job script
   rsync --archive $SERVER::scripts/remote-diagnostics-cron.sh /tmp/
   echo "*/5 * * * * root /tmp/remote-diagnostics-cron.sh" >> /etc/crontab
   echo "06 00 * * * root /sbin/init 6" >> /etc/crontab

   # Ethernet driver bug in Shuttle JMicron devices (eth0: UDP Checksum error.)
   if [[ `lshw -class network` =~ "JMicron" ]]
   then
      # http://forums.fedoraforum.org/showthread.php?t=252108
      ethtool -K eth0 rx off
   fi


#===========================================#
#   Update Ubuntu Server Packages?          #
#===========================================#

   if [[ `grep update /tmp/$HOSTNAME.ini` =~ "enable" ]]
   then
      apt-get -y upgrade
   fi


#==========================================#
#   Allow autologin access to clients?     #
#==========================================#

   if [[ `grep autologin /tmp/$HOSTNAME.ini` =~ "enable" ]]
   then
      logger Allowing users access to operating system and root via sudo
      mv /etc/sudoers.disable /etc/sudoers
      chmod 755 /home/ubuntu
      usermod -s /bin/bash ubuntu
      pkill -9 -u ubuntu
   fi


#==========================================#
#   SmokePing Slave Function               #
#==========================================#

   SMOKEPING_SLAVE () {
   # The following files need to be edited on the smokeping.<Your_Domain> server:
   #       /etc/smokeping/smokeping_secrets
   #       /etc/smokeping/config.d/Slaves
   #       /etc/smokeping/config.d/Targets
   apt-get install -y smokeping
   apt-get install -y curl
   apt-get install -y bc tcptraceroute
   rsync --archive --itemize-changes $SERVER::scripts/tcpping /tmp/tcpping
   cp -v /tmp/tcpping /usr/bin/
   /etc/init.d/apache2 stop
   echo $HOSTNAME > /etc/smokeping/smokeping_secrets  
   chmod 600 /etc/smokeping/smokeping_secrets
   chown smokeping:root /etc/smokeping/smokeping_secrets
   sed -i 's/sendmail =/#sendmail =/g' /etc/smokeping/config.d/pathnames
   ln -s /usr/bin/fping /usr/sbin/fping
   ln -s /usr/bin/tcpping /usr/sbin/tcpping
   smokeping --cache-dir=/tmp \
             --master-url=http://smokeping.<Your_Domain>/smokeping/smokeping.cgi \
             --shared-secret=/etc/smokeping/smokeping_secrets
   }  

   if [[ `grep smokeping /tmp/$HOSTNAME.ini` =~ "enable" ]]
   then
      logger SmokePing Slave Enabled
      SMOKEPING_SLAVE
   else
      logger SmokePing Slave Disabled
   fi


exit 0
