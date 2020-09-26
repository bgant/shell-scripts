#!/bin/bash

#===================================================

# Swap Percentage that triggers e-mail notifications
THRESHOLD="20"

# Swap Percentage that triggers a server reboot
REBOOT="60"

#===================================================

function RebootServer {
   echo "Rebooting Server"
   /usr/bin/pkill -9 httpd
   OUTPUT=`top -b -n 1`
   echo "$OUTPUT" | /usr/local/bin/sendEmail -q -f `hostname --short`@<Your_Domain> -t "alerts@<Your_Domain>" -o tls=no -s <Your_SMTP_Server>:25 -u "`hostname`: Swap Utilization threshold reached (${PERCENTAGE}%)... Rebooting Server"
   ( /etc/init.d/sfxd stop ) &
   sleep 30
   /sbin/shutdown -r +1
}

function SendEmail {
  # The quotes around the $OUTPUT variable name preserves the line breaks
  OUTPUT=`top -b -n 1`
  echo "Sending E-mail"
  echo "$OUTPUT" | /usr/local/bin/sendEmail -q -f `hostname --short`@<Your_Domain> -t "alerts@<Your_Domain>" -o tls=no -s <Your_SMTP_Server>:25 -u "`hostname`: Swap Utilization at ${PERCENTAGE}%"
}

function ThresholdCheck {
   # Remove disk files if the Use% drops below threshold
   if [ -e "/tmp/swap.$THRESHOLD" ] && [ $PERCENTAGE -lt $THRESHOLD ]
   then
      #echo "Removing /tmp/swap.$THRESHOLD"
      rm /tmp/swap.$THRESHOLD
   fi

   # Create disk file and Send E-mail if Percentage is above Threshold
   if [ $PERCENTAGE -ge $THRESHOLD ]
   then
     if [ ! -e "/tmp/swap.$THRESHOLD" ]
     then
        touch /tmp/swap.$THRESHOLD
        # Only send one e-mail if swap usage jumps higher
        DIFF=`expr $PERCENTAGE - $THRESHOLD`
        if [ $DIFF -lt "10" ]
        then
           SendEmail
        fi
     fi
   fi
}

SWAP=`free -g -o | grep "Swap"`
SWAPTOTAL=`echo $SWAP | awk -F' ' '{print $2}'`
if [ $SWAPTOTAL -eq "0" ]
then
   echo "Swap Utilization is 0%"
   exit 0
fi
SWAPUSED=`echo $SWAP | awk -F' ' '{print $3}'`
PERCENTAGE=`expr 100 \* $SWAPUSED / $SWAPTOTAL`

# Use the following to test the script
#PERCENTAGE="45"

echo
echo "Swap Utilization is $PERCENTAGE% [${SWAPUSED}/${SWAPTOTAL}GB]"
echo

# Loop through incrementally higher threshold numbers
until [ $THRESHOLD -gt $REBOOT ]; do
   ThresholdCheck
   #echo "threshold is $THRESHOLD"
   THRESHOLD=$(( $THRESHOLD + 10 ))
done

if [ $PERCENTAGE -ge $REBOOT ]
then
   RebootServer
fi

