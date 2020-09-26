#!/bin/bash
#
# Brandon Gant
# 2016-01-07
#
# Usage: /root/scripts/disk-check.sh sda2
#
# Works on CentOS and Ubuntu
#

SERVER=`hostname -s`
OS=`head -n1 /etc/issue`
DF=`df -h`

# Exit script when zero-deleted-data.sh is running
ZERO=`ps -e -o args | grep -v grep | grep zero-deleted-data.sh`
if [ -n "$ZERO" ]
then
   echo "zero-deleted-data.sh script is running... Exiting"
   exit 0
fi

function ValidVolumes {
   df | grep sd | awk -F' ' '{print $1" "$6}' | cut --complement -c 1-5
}

# Make sure at least one disk is specified
if [ -z "$1" ]
then
   echo "Specify one or more volumes to monitor... Here is a list:"
   ValidVolumes
   echo "Example: /root/scripts/disk-check.sh sda2 sda1 sdb1"
   exit 0
fi

for DISK in "$1" "$2" "$3" "$4" "$5"
do

# Stop running if there are no more disks to check
if [ -z "$DISK" ]
then
   break  # Skip entire rest of loop
fi

# Make sure it is a valid volume
CHECK=`echo "$DF" | awk -F' ' '{print $1}' | cut --complement -c1-5 | grep -m1 "$DISK"`
if [ -z "$CHECK" ]
then
   echo "Volume $DISK is not valid... Here is a list of valid volumes:"
   ValidVolumes
   exit 0
else
   if [[ "$DISK" =~ "sd"[a-z][0-9] ]]
   then 
      echo "$DISK is valid... Checking..."
   else
      echo "Volume "$DISK" is not valid... Here is a list of valid volumes:"
      ValidVolumes
      exit 0
   fi
fi

# Send an e-mail alert
function SendEmail {
     sendEmail -f $SERVER@<Your_Domain> \
               -t alerts@<Your_Domain> \
               -s <Your_SMTP_Server>:25 \
               -o tls=no \
               -u "${SERVER} Disk Usage at ${NOW}%" \
               -m "$DF"
}

# Get current disk utilization
NOW=`df | grep "$DISK" | awk -F' ' '{print $5}' | awk -F'%' '{print $1}'`

# Keep track of disk utilization
for i in 99 97 95 93 91
do
   FILE="/root/scripts/disk-check.$DISK.$i"

   # As disk usage increases
   if [ "$NOW" -eq "$i" ]
   then 
      if [ ! -e "$FILE" ]
      then
         touch "$FILE"
         echo "${DISK} at ${NOW}%... Sending E-mail..."
         SendEmail
      fi
   fi

   # As disk usage decreases
   if [ "$NOW" -lt "$i" ]
   then
      if [ -e "$FILE" ]
      then
         echo -n "${DISK} utilization has decreased... "
         rm -v "$FILE"
      fi
   fi   
done

done

exit 0
