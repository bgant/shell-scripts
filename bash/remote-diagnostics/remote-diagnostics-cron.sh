#!/bin/bash
# This script is run via /etc/crontab

SERVER="remote-diagnostics.<Your_Domain>"
MAIN_SCRIPT="remote-diagnostics-initialization.sh"
CRON_SCRIPT="remote-diagnostics-cron.sh"
HOSTNAME=`uname -n`

# Simple check to see if everything is running
date > /tmp/heartbeat.log

# Upload stuff to server in case I need to debug them
UPLOAD () {
rsync --archive /tmp/ $SERVER::clients/$HOSTNAME/
rsync --archive /var/log/syslog $SERVER::clients/$HOSTNAME/
}
UPLOAD

#=======================================================#
#   Check for new versions of scripts                   #
#=======================================================#

# Check for new cron script
rsync --archive $SERVER::scripts/$CRON_SCRIPT /tmp/

# Reboot if new initialization script or ini file is available
RSYNC="rsync --archive --itemize-changes --modify-window=10 --dry-run $SERVER::scripts"
if [ -n "`$RSYNC/$MAIN_SCRIPT /tmp/`" ] || [ -n "`$RSYNC/$HOSTNAME.ini /tmp/`" ]
then
   echo "`date`: rebooting to load new initialization or ini file" > /tmp/reboot.log
   UPLOAD
   ( shutdown -r now "New script is available..." ) &
   exit 0
fi

# Log if device was just booted up
if [ -n "`uptime | grep " [1-6] min,"`" ]
then
   echo "`date`: device restarted" > /tmp/reboot.log
   UPLOAD
fi


#=======================================================#
#   Run traceroute and log results                      #
#=======================================================#

if [[ `grep traceroute /tmp/$HOSTNAME.ini` =~ "enable" ]]
then
   logger Traceroute <Local_Server>
   traceroute -q 1 -N 1 <Local_Server> | grep -v traceroute | awk -F' ' '{print $2}' | grep -v \* | tr [:upper:] [:lower:] > /tmp/traceroute.log
fi


#=======================================================#
#   Fault Analysis                                      #
#=======================================================#

if [[ `grep fault-analysis /tmp/$HOSTNAME.ini` =~ "enable" ]]
then
 
   # Is the circsvr port specified for this host in the ini file?
   CIRCSVR=`grep circsvr /tmp/$HOSTNAME.ini | awk -F'=' '{print $2}'`
   if [ -n "$CIRCSVR" ]
   then

      VOYAGER="<Local_Server>" 
      DEPT="http://<Local_Department_Website>"
      UIUC="http://<Local_Campus_Website>"
      OTHER="http://www.google.com"
      GATEWAY=`route -n | egrep -v "Kernel|Destination" | awk -F' ' '{print $2}' | grep -v 0.0.0.0`
      FAULTLOG="/tmp/fault-analysis.log"

      # Is the circsvr port responding?
      if [[ `nmap -PN -p $CIRCSVR $VOYAGER` =~ "tcp open" ]]
      then
         echo "$VOYAGER circsvr $CIRCSVR is responding" > $FAULTLOG
      # Is the Voyager server responding to pings?
      elif [[ `nmap -sP $VOYAGER` =~ "is up" ]]
      then
         echo "$VOYAGER circsvr $CIRCSVR OFFLINE" > $FAULTLOG
         echo "$VOYAGER is responding to pings" >> $FAULTLOG
      # Are other DEPT services available?
      elif [ -n "`wget --quiet -O - $DEPT`" ]
      then
         echo "$VOYAGER circsvr $CIRCSVR OFFLINE" > $FAULTLOG
         echo "$VOYAGER is NOT responding to pings" >> $FAULTLOG
         echo "$DEPT is responding to wget" >> $FAULTLOG
      # Are other UIUC services available?
      elif [ -n "`wget --quiet -O - $UIUC`" ]
      then
         echo "$VOYAGER circsvr $CIRCSVR OFFLINE" > $FAULTLOG
         echo "$VOYAGER is NOT responding to pings" >> $FAULTLOG
         echo "$DEPT is NOT responding to wget" >> $FAULTLOG
         echo "$UIUC is responding to wget" >> $FAULTLOG
      # Any Internet websites available?
      elif [ -n "`wget --quiet -O - $OTHER`" ]
      then
         echo "$VOYAGER circsvr $CIRCSVR OFFLINE" > $FAULTLOG
         echo "$VOYAGER is NOT responding to pings" >> $FAULTLOG
         echo "$DEPT is NOT responding to wget" >> $FAULTLOG
         echo "$UIUC is NOT responding to wget" >> $FAULTLOG
         echo "$OTHER is responding to wget" >> $FAULTLOG
      # Is the Default Gateway responding?
      elif [[ `nmap -sP $GATEWAY` =~ "is up" ]]
      then
         echo "$VOYAGER circsvr $CIRCSVR OFFLINE" > $FAULTLOG
         echo "$VOYAGER is NOT responding to pings" >> $FAULTLOG
         echo "$DEPT is NOT responding to wget" >> $FAULTLOG
         echo "$UIUC is NOT responding to wget" >> $FAULTLOG
         echo "$OTHER is NOT responding to wget" >> $FAULTLOG
         echo "Default Gateway $GATEWAY is responding to pings" >> $FAULTLOG
      else
         echo "Local Default Gateway $GATEWAY NOT responding to pings" > $FAULTLOG
         echo "Network connection appears to be offline. Rebooting." >> $FAULTLOG
         shutdown -r +1 "Network connection down"
      fi

   else
      logger Fault Analysis: circsvr port not specified in ini
   fi
fi


#=======================================================#
#   Netcat Idle Timeout Check                           #
#=======================================================#

if [[ `grep idle-timeout /tmp/$HOSTNAME.ini` =~ "enable" ]]
then
   for SEC in 300 900 3600 7200 14400
   do
      if [ -z "`ps -e -o args | egrep -v "grep|defunct" | grep netcat$SEC`" ]
      then
         logger Idle Timeout: Starting up netcat$SEC $VOYAGER $CIRCSVR
         if [ ! -e /tmp/netcat$SEC ]
         then
            ln -s /bin/netcat /tmp/netcat$SEC
         fi
         {
           while true
           do
              echo "DEPTnetcat$SEC"
              sleep $SEC
           done
         } | /tmp/netcat$SEC -v $VOYAGER $CIRCSVR &
      fi
   done
   ps -e -o lstart -o args | egrep -v "grep|defunct" | grep netcat | cut --complement --characters 17-19 > /tmp/idle-timeout.log
fi


#=======================================================#
#   Watch local LAN with ethtool                        #
#=======================================================#

if [[ `grep local-lan /tmp/$HOSTNAME.ini` =~ "enable" ]]
then
   ethtool eth0 > /tmp/local-lan.log
fi


exit 0
