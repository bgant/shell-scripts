#!/bin/bash
#
# Script to monitor how SMTP servers are being used
#
# Brandon Gant
# Updated: 2016-10-31
#
# Run in crontab after midnight to look at e-mails Sent yesterday
#   #-------- Daily SMTP Stats
#   30 00 * * * root /root/scripts/smtp-daily-stats.sh > /dev/null 2>&1

YESTERDAY=`date +%b" "%e -d "yesterday"`

# Total number of e-mails Sent yesterday
TOTAL=`cat /var/log/maillog* | grep ^"$YESTERDAY" | grep to= | grep status=sent | wc -l`

# Total number of e-mails Sent yesterday per Domain name
OUTPUT=`cat /var/log/maillog* | grep ^"$YESTERDAY" | grep to= | grep status=sent | egrep -v "reject:|noreply@<Your_Domain>" | awk -F' ' '{print $7}' | awk -F'@' '{print $2}' | awk -F'>' '{print $1}' | sort --ignore-case | uniq -c --ignore-case | sort -nr | grep -v " [0-9] "`

# E-mail results
echo -e "<less than 10 truncated>\n$OUTPUT" | /usr/local/bin/sendemail -f `hostname --short`@<Your_Domain> -t alerts@<Your_Domain> -s <Your_SMTP_Server> -o tls=no -u "Daily SMTP Stats: ${TOTAL}" 

exit 0
