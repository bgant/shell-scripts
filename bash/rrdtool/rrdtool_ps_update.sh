#!/bin/bash

# Brandon Gant 2009-11-03

###########################################################
#               Installation Instructions
###########################################################
#
# Install the following (or newer) sunfreeware.com packages
# on each Voyager/WebVoyage server:
#
#   sudo pkgadd -d rrdtool-1.2.19-sol10-sparc-local
#   sudo pkgadd -d libpng-1.2.40-sol10-sparc-local
#   sudo pkgadd -d libart_lgpl-2.3.19-sol10-sparc-local
#   sudo pkgadd -d freetype-2.3.9-sol10-sparc-local
#
#   ln -s /usr/local/rrdtool-1.2.19 /usr/local/rrdtool
#
#   mkdir /opt/rrdtool (if it does not exist)
#
# Add the following to the crontab:
#
#   #------ Update RRD files with ps output
#   0,5,10,15,20,25,30,35,40,45,50,55 * * * * /opt/rrdtool/scripts/rrdtool_ps_update.sh > /dev/null 2>&1
#
##########################################################

SERVER=`uname -n | cut -d"." -f1`

#---------------------------------------------------------
# Subroutine to update the rrd files
#---------------------------------------------------------

rrdupdate() {

# SERVER is $1
# LIB is $2
# FNAME is $3
# COUNT is $4

DATA="$4"
if [ -z $DATA ]
then 
   DATA="0"
fi

RRDFILE="/opt/rrdfiles/$1_$2_$3.rrd"

if [ -e $RRDFILE ]
then
        echo "Updating $RRDFILE with count $DATA"
        rrdtool update $RRDFILE N:$DATA
else
        echo "Creating $RRDFILE"
        rrdtool create $RRDFILE DS:Data:GAUGE:600:U:U \
        RRA:AVERAGE:0.5:1:600 RRA:AVERAGE:0.5:6:700 RRA:AVERAGE:0.5:24:775 RRA:AVERAGE:0.5:288:1895 \
        RRA:MAX:0.5:1:600 RRA:MAX:0.5:6:700 RRA:MAX:0.5:24:775 RRA:MAX:0.5:288:1895 \
        RRA:MIN:0.5:1:600 RRA:MIN:0.5:6:700 RRA:MIN:0.5:24:775 RRA:MIN:0.5:288:1895
fi
}


#-----------------------------------------------------------
# This section takes the ps output and categorizes it 
#-----------------------------------------------------------

defaultIFS=$IFS  # current separator in for loop
IFS=$'\n'        # new field separator: end of line 

for LINE in `ps -e -o fname -o args | sort | uniq -c` 
do
    COUNT=`echo $LINE | awk -F" " '{print $1}'`
    FNAME=`echo $LINE | awk -F" " '{print $2}'`
    ARGS=`echo $LINE | awk -F" " '{print $3" "$4" "$5" "$6" "$7}'`
    LIB=`expr match "$ARGS" '.*\([A-Z][A-Z][A-Z]\)db.*'` || LIB=`expr match "$ARGS" '.*\([A-Z][A-Z][A-Z]\)DB.*'` || LIB=`expr match "$ARGS" '.*\(uc\)db.*'` || LIB=`expr match "$ARGS" '.*\(UC\)DB.*'` || LIB="ALL"

#-----------------------------------------------------------
# I don't like "uc" and prefer a three-letter code
#-----------------------------------------------------------

    if [ "$LIB" == "uc" ]
    then 
       LIB="UCC"
    fi

    if [ "$LIB" == "UC" ]
    then
       LIB="UCC"
    fi

#-----------------------------------------------------------
# This is where I deal with everything that is not owned by 
# a three-letter code library.
#-----------------------------------------------------------

    if [ "$LIB" == "ALL" ]
    then 
       if [ "$FNAME" == "webvoyag" ]
       then
          WEBVOYAG=$(($WEBVOYAG + $COUNT))
       elif [ "$FNAME" == "webrecon" ]
       then
          WEBRECON=$(($WEBRECON + $COUNT))
       elif [ "$FNAME" == "encrypt_" ]
       then
          ENCRYPT=$(($ENCRYPT + $COUNT))
       elif [ "$FNAME" == "socat" ]
       then
          SOCAT=$(($SOCAT + $COUNT))
       elif [ "$FNAME" == "httpd" ]
       then
          HTTPD=$(($HTTPD + $COUNT))
       else 
          OTHER=$(($OTHER + $COUNT))
       fi
    else
       #echo "$LIB:$FNAME:$COUNT"
       rrdupdate $SERVER $LIB $FNAME $COUNT
    fi

done

IFS=$defaultIFS  # Set the delimiter back to default

#---------------------------------------------------------
# Special processing for all the "other" processes
#---------------------------------------------------------

# What are we counting?
# opacsvr keysvr circsvr catsvr callslip acqsvr z3950svr mhs_msg mediasvr rptsvr selfchk 
# bulkimpo java httpd webvoyag webrecon socat encrypt_ <defunct
# other (ALL)

rrdupdate $SERVER ALL webvoyag $WEBVOYAG
rrdupdate $SERVER ALL webrecon $WEBRECON
rrdupdate $SERVER ALL socat $SOCAT
rrdupdate $SERVER ALL encrypt $ENCRYPT
rrdupdate $SERVER ALL httpd $HTTPD
rrdupdate $SERVER ALL other $OTHER

