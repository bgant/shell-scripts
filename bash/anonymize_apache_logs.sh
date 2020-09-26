#!/bin/bash
#
# Created: 2013-02-14 by Brandon Gant
#
# Add the following to /etc/crontab:
#    #-------- anonymize and gzip apache log files daily
#    10 00   * * * /root/scripts/anonymize_apache_logs.sh > /dev/null 2>&1

# This should only be run on Production
if [ `uname -n` = "<Prod_Server>" ]
then

DIR="/var/log/httpd"

# Delimiter Character: A6 is Hex ASCII Value for "Pipe, Broken vertical bar"
D=`printf "\xA6\n"`

# You can specify a file to anonymize if one was missed
if [ -n "$1" ]
then
   LOGFILE="$1"
else
   LOGFILE="access_log.`date -d '1 day ago' +%Y%m%d`"
fi

# Anonymizer Commands:
#    Replace AppleWebKit double Client IP's "x.x.x.x, x.x.x.x" with "0.0.0.0"
#    Insert delimiters to make parsing easier
#    Replace Client IP Address ($3) with 0.0.0.0 and Referring URL ($5) with "-"

if [ -e $DIR/$LOGFILE ]
then

echo "Anonymizing $LOGFILE..."
cat $DIR/$LOGFILE | \
          nice sed 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\, [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)/0.0.0.0/g' | \
          nice sed "s/^\(.*\) \(.*\) \(.*\) \(.* .* \[.*\] \".*\" .* .*\) \(\".*\"\) \(\".*\" .* .*\)$/\1$D\2$D\3$D\4$D\5$D\6/g" | \
          nice awk -F"$D" '{print $1 " " $2 " 0.0.0.0 " $4 " \"-\" " $6}' > $DIR/$LOGFILE.tmp

# Copy over the original Apache log file
echo "Replacing $LOGFILE with $LOGFILE.tmp..."
mv $DIR/$LOGFILE.tmp $DIR/$LOGFILE

# gzip the new anonymized log file
echo "Gzip'ing $LOGFILE..."
gzip -vf $DIR/$LOGFILE

# Copy anonymized logs over to the Main website
echo "Sending anonymized files to website..."
#/root/scripts/rsync-logs.sh > /dev/null 2>&1
/root/scripts/rsync-logs.sh

else
   echo "$LOGFILE does not exist. Nothing to anonymize."
fi

else
   echo "This script only works on Production"
fi

exit 0

# if 
# gzip -dc /opt/apache/logs/access_log.20130221.gz | /usr/local/bin/gawk -F' ' '{print $3}' | grep -vc '0.0.0.0'
# does not equal zero
# something is wrong with anonymize script

