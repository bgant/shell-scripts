#!/bin/bash
#
# Changes to default /etc/aide.conf or /etc/aide/aide.conf
#     database=file:@@{DBDIR}/aide.db.check
#     database_out=file:@@{DBDIR}/aide.db.init
#     gzip_dbout=no   # Gzipped db broken in version 0.13.1 - Brandon
#
#     /lib64  NORMAL  # Added by Brandon
#
#     # Files that update frequently - Brandon
#     !/etc/yum.repos.d/redhat.repo
#     !/var/log/rpmpkgs
#     !/var/log/lastlog
#     !/var/log/aide/
#
#     # Files that change after reboot - Brandon
#     !/etc/sysconfig/hwconf
#     !/etc/blkid/
#     !/etc/aliases.db
#     !/var/run/utmp
#
# Get sendEmail perl script for CentOS:
#     wget http://caspian.dotconf.net/menu/Software/SendEmail/sendEmail-v1.56.tar.gz
#     chmod +x sendemail
#     cp sendEmail /usr/local/bin/
#

# Check to see if it is already running...
LOCKFILE="/var/run/aide-check.pid"
if [ -e $LOCKFILE ]
then
   echo "Script is already running (see $LOCKFILE)... Exiting"
   exit 0
else
   # Create Lock File
   echo $$ > $LOCKFILE
fi

case `head --lines=1 /etc/issue` in
'Ubuntu'*)
    echo "I am Debian based Linux..."
    NICE="/usr/bin/nice"
    INIT="$NICE /usr/sbin/aideinit --yes --force"
    CHECK="$NICE /usr/bin/aide.wrapper --check"
    SENDEMAIL="/usr/bin/sendEmail"
    CONFIG="/etc/aide/aide.conf"
    if [ ! -e $SENDEMAIL ]
    then
       apt-get -y install sendEmail
    fi
    ;;
'Red Hat'*|'CentOS'*)
    echo "I am Red Hat based Linux..."
    AIDE="/usr/sbin/aide"
    NICE="/bin/nice"
    INIT="$NICE $AIDE --init --verbose=200"
    CHECK="$NICE $AIDE --check"
    SENDEMAIL="/usr/local/bin/sendEmail"
    CONFIG="/etc/aide.conf"
    ;;
*)
    echo "I don't know what operating system I am running on... Exiting"
    rm $LOCKFILE
    exit 0
esac

SERVER=`uname -n | awk -F'.' '{print $1}'`
MESSAGE=`$CHECK` 
echo "$MESSAGE" > /var/log/aide/aide-`date +%Y-%m-%d-%H%M`.log

# Send E-mail
if [[ "$MESSAGE" =~ "okay" ]]
then
   echo "All files match AIDE database. Looks okay!"
else

   echo "$MESSAGE" | $SENDEMAIL -f $SERVER@<Your_Domain>                                 \
                                              -t alerts@<Your_Domain>                    \
                                              -s <Your_SMTP_Server>                      \
                                              -u "AIDE File System Check: $SERVER" 

   # Reset AIDE so that it detects new changes
   # (Run these commands to initialize for the first time)
   $INIT
   rsync --archive --progress /var/lib/aide/aide.db.init /var/lib/aide/aide.db.check

fi

rm $LOCKFILE
exit 0
