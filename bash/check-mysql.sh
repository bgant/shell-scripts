#!/bin/bash
#
# Brandon Gant
# 2017-03-14
#
# This script checks to see if MySQL has crashed
#

APACHE=`netstat -tln | grep :80`
MYSQL=`netstat -tln | grep :1720`

# If $MYSQL is null
if [ -z "$MYSQL" ]
then
   # If $APACHE is NOT null
   if [ -n "$APACHE" ]
   then
      echo "Restarting MySQL..."
      service mysql restart
   else
      echo "Apache is off, so this script assumes someone is doing maintenance... Exiting"
   fi
else
   echo "MySQL is running... Exiting"
fi

exit 0

